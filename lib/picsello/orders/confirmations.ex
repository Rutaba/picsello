defmodule Picsello.Orders.Confirmations do
  @moduledoc "context module for confirming orders. Should be accessed through Cart."

  alias Picsello.{Invoices.Invoice, Galleries, Cart.Order, Payments, Cart.OrderNumber, WHCC, Repo}
  import Ecto.Query, only: [from: 2]
  import Ecto.Multi, only: [new: 0, put: 3, update: 3, run: 3]

  @doc """
  Handles a stripe session.

  1. query for order and connect account
  1. make sure the order isn't already paid
  1. maybe fetch the session
  1. update intent
  1. is client paid up?
    1. send confirmation email
    1. is the order all paid for?
      1. capture the stripe funds
      1. confirm with whcc
  """
  def handle_session(
        %Stripe.Session{client_reference_id: "order_number_" <> order_number} = session,
        helpers
      ) do
    do_confirm_order(order_number, &Ecto.Multi.put(&1, :session, session), helpers)
  end

  def handle_session(order_number, stripe_session_id, helpers) do
    do_confirm_order(
      order_number,
      &Ecto.Multi.run(&1, :session, __MODULE__, :fetch_session, [stripe_session_id]),
      helpers
    )
  end

  @doc """
  Handles a stripe invoice.

  1. query for existing invoice
  1. updates existing invoice with stripe info
  1. is order all paid for?
      1. capture client funds
      1. confirm with whcc
  """
  def handle_invoice(invoice) do
    new()
    |> put(:stripe_invoice, invoice)
    |> run(:invoice, &load_invoice/2)
    |> update(:updated_invoice, &update_invoice_changeset/1)
    |> Repo.transaction()
  end

  defp do_confirm_order(order_number, session_fn, helpers) do
    new()
    |> put(:order_number, order_number)
    |> run(:order, &load_order/2)
    |> run(:stripe_options, &stripe_options/2)
    |> run(:paid, &check_paid/2)
    |> session_fn.()
    |> run(:intent, &update_intent/2)
    |> update(:confirmed_order, &confirm_order_changeset/1)
    |> run(:capture, &capture/2)
    |> Repo.transaction()
    |> case do
      {:error, :paid, true, %{order: order}} ->
        {:ok, order}

      {:ok, %{confirmed_order: order}} ->
        send_confirmation_email(order, helpers)
        {:ok, order}

      {:error, _, _, %{session: %{payment_intent: intent_id}, stripe_options: stripe_options}} =
          error ->
        Payments.cancel_payment_intent(intent_id, stripe_options)
        error

      other ->
        other
    end
  end

  defp load_order(repo, %{order_number: order_number}) do
    order_id = OrderNumber.from_number(order_number)

    order =
      from(order in Order,
        where: order.id == ^order_id,
        preload: [
          products: :whcc_product,
          digitals: :photo,
          gallery: [job: [client: :organization]]
        ]
      )
      |> repo.one!()

    {:ok, order}
  end

  defp stripe_options(_, %{order: order}) do
    case order do
      %{gallery: %{job: %{client: %{organization: %{stripe_account_id: stripe_account_id}}}}} ->
        {:ok, connect_account: stripe_account_id}

      _ ->
        {:error, "no connect account"}
    end
  end

  defp check_paid(_, %{order: order}) do
    if Picsello.Orders.client_paid?(order) do
      {:error, true}
    else
      {:ok, false}
    end
  end

  def fetch_session(
        _repo,
        %{order_number: order_number, stripe_options: stripe_options},
        session_id
      ) do
    case Payments.retrieve_session(session_id, stripe_options) do
      {:ok, %{client_reference_id: "order_number_" <> ^order_number} = session} ->
        {:ok, session}

      {:ok, session} ->
        {:error, "unexpected session:\n#{inspect(session)}"}

      error ->
        error
    end
  end

  defp update_intent(_, %{
         session: %{payment_intent: intent_id},
         order: order,
         stripe_options: stripe_options
       }) do
    %{amount: total} = Order.total_cost(order)

    case Payments.retrieve_payment_intent(intent_id, stripe_options) do
      {:ok, %{amount_capturable: ^total} = intent} ->
        Picsello.Intents.update(intent)

      {:ok, intent} ->
        {:error, "cart total does not match payment intent:\n#{inspect(intent)}"}

      error ->
        error
    end
  end

  defp confirm_order_changeset(%{
         order:
           %Order{
             gallery: gallery,
             products: [_ | _],
             whcc_order: %{confirmation_id: confirmation_id}
           } = order
       }) do
    {:ok, confirmation_result} =
      gallery |> Galleries.account_id() |> WHCC.confirm_order(confirmation_id)

    Order.confirmation_changeset(order, confirmation_result)
  end

  defp confirm_order_changeset(%{
         order:
           %Order{
             products: [],
             digitals: digitals,
             whcc_order: nil,
             bundle_price: bundle_price
           } = order
       })
       when digitals != [] or not is_nil(bundle_price),
       do: Order.confirmation_changeset(order)

  defp capture(_repo, %{intent: intent, stripe_options: stripe_options}) do
    case Picsello.Intents.capture(intent, stripe_options) do
      {:ok, %{status: :succeeded} = intent} ->
        {:ok, intent}

      error ->
        error
    end
  end

  defp send_confirmation_email(order, helpers) do
    Picsello.Notifiers.ClientNotifier.deliver_order_confirmation(order, helpers)
  end

  defp load_invoice(repo, %{stripe_invoice: %Stripe.Invoice{id: stripe_id}}) do
    Invoice
    |> repo.get_by(stripe_id: stripe_id)
    |> case do
      nil -> {:error, "no invoice"}
      invoice -> {:ok, invoice}
    end
  end

  defp update_invoice_changeset(%{stripe_invoice: stripe_invoice, invoice: invoice}) do
    Invoice.changeset(invoice, stripe_invoice)
  end
end
