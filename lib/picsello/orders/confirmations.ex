defmodule Picsello.Orders.Confirmations do
  @moduledoc """
    Context module for handling order payments.

    These are the steps that occur when we hear from stripe about an order payment from a photographer or their client.

    See also Picsello.Cart.Checkouts for the steps that come before this in the ordering process.
  """

  alias Picsello.{
    Invoices,
    Invoices.Invoice,
    Galleries,
    Cart.Order,
    Payments,
    Cart.OrderNumber,
    WHCC,
    Repo
  }

  import Ecto.Query, only: [from: 2]
  import Money.Sigils
  import Ecto.Multi, only: [new: 0, put: 3, update: 3, run: 3, merge: 2, append: 2, insert: 3]

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
     1. photographer still owes?
        1. insert photographer invoice
        1. finalize photographer invoice
  """
  @spec handle_session(Stripe.Session.t()) ::
          {:ok, Order.t(), :confirmed | :already_confirmed} | {:error, any()}
  def handle_session(
        %Stripe.Session{client_reference_id: "order_number_" <> order_number} = session
      ) do
    do_confirm_order(order_number, &Ecto.Multi.put(&1, :session, session))
  end

  @spec handle_session(String.t(), String.t()) ::
          {:ok, Order.t(), :confirmed | :already_confirmed} | {:error, any()}
  def handle_session(order_number, stripe_session_id) do
    do_confirm_order(
      order_number,
      &Ecto.Multi.run(&1, :session, __MODULE__, :fetch_session, [stripe_session_id])
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
    |> merge(fn
      %{updated_invoice: %{order: %{intent: intent} = order, status: :paid}} ->
        new()
        |> run(:confirm_order, fn _, _ -> confirm_order(order) end)
        |> update(:order, Order.whcc_confirmation_changeset(order))
        |> append(handle_capture(intent, order))

      _ ->
        new()
    end)
    |> Repo.transaction()
  end

  defp handle_capture(nil, _), do: new()

  defp handle_capture(intent, order) do
    new() |> run(:capture, fn _, _ -> capture(intent, stripe_options(order)) end)
  end

  defp do_confirm_order(order_number, session_fn) do
    new()
    |> put(:order_number, order_number)
    |> run(:order, &load_order/2)
    |> run(:stripe_options, &stripe_options/2)
    |> session_fn.()
    |> run(:client_paid, &check_paid/2)
    |> update(:place_order, &place_order/1)
    |> run(:intent, &update_intent/2)
    |> run(:photographer_owes, &photographer_owes/2)
    |> merge(fn
      %{order: %{products: [_ | _]} = order, photographer_owes: ~M[0]USD} = multi ->
        new()
        |> run(:confirm_order, fn _, _ -> confirm_order(order) end)
        |> update(:confirmed_order, Order.whcc_confirmation_changeset(order))
        |> run(:capture, fn _, _ -> capture(multi) end)

      %{order: %{products: []}} = multi ->
        run(new(), :capture, fn _, _ -> capture(multi) end)

      %{order: order, photographer_owes: photographer_owes} ->
        new()
        |> run(:stripe_invoice, fn _, _ -> create_stripe_invoice(order, photographer_owes) end)
        |> insert(:invoice, &insert_invoice_changeset(&1, order))
    end)
    |> Repo.transaction()
    |> case do
      {:error, :client_paid, _, %{order: order}} ->
        {:ok, order, :already_confirmed}

      {:ok, %{place_order: order}} ->
        {:ok, order, :confirmed}

      {:error, _, _, %{session: %{payment_intent: intent_id}, stripe_options: stripe_options}} =
          error ->
        Payments.cancel_payment_intent(intent_id, stripe_options)
        error

      other ->
        other
    end
  end

  defp photographer_owes(_repo, %{order: %{whcc_order: nil}}), do: {:ok, ~M[0]USD}

  defp photographer_owes(_repo, %{
         intent: %{application_fee_amount: nil},
         order: %{whcc_order: whcc_order}
       }),
       do: {:ok, Picsello.WHCC.Order.Created.total(whcc_order)}

  defp photographer_owes(_repo, %{
         intent: %{application_fee_amount: application_fee_amount},
         order: %{whcc_order: whcc_order}
       }),
       do:
         {:ok,
          whcc_order
          |> Picsello.WHCC.Order.Created.total()
          |> Money.subtract(application_fee_amount)}

  defp place_order(%{order: order}), do: Order.placed_changeset(order)

  defp load_order(repo, %{order_number: order_number}) do
    order_id = OrderNumber.from_number(order_number)

    order =
      from(order in Order,
        where: order.id == ^order_id,
        preload: [
          products: :whcc_product,
          digitals: :photo,
          gallery: [organization: :user]
        ]
      )
      |> repo.one()

    {:ok, order}
  end

  defp stripe_options(_, %{order: order}) do
    case order do
      %{gallery: %{organization: %{stripe_account_id: stripe_account_id}}} ->
        {:ok, connect_account: stripe_account_id}

      _ ->
        {:error, "no connect account"}
    end
  end

  defp stripe_options(%{gallery: %{organization: %{stripe_account_id: stripe_account_id}}}),
    do: [connect_account: stripe_account_id]

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
         stripe_options: stripe_options
       }) do
    case Payments.retrieve_payment_intent(intent_id, stripe_options) do
      {:ok, intent} ->
        Picsello.Intents.update(intent)

      error ->
        error
    end
  end

  defp confirm_order(%Order{
         gallery_id: gallery_id,
         whcc_order: %{confirmation_id: confirmation_id}
       }) do
    gallery_id |> Galleries.account_id() |> WHCC.confirm_order(confirmation_id)
  end

  defp capture(%{intent: intent, stripe_options: stripe_options}) do
    capture(intent, stripe_options)
  end

  defp capture(intent, options) do
    case Picsello.Intents.capture(intent, options) do
      {:ok, %{status: :succeeded} = intent} ->
        {:ok, intent}

      error ->
        error
    end
  end

  defp load_invoice(repo, %{stripe_invoice: %Stripe.Invoice{id: stripe_id}}) do
    Invoice
    |> repo.get_by(stripe_id: stripe_id)
    |> case do
      nil -> {:error, "no invoice"}
      invoice -> {:ok, repo.preload(invoice, order: [:intent, gallery: :organization])}
    end
  end

  defp update_invoice_changeset(%{stripe_invoice: stripe_invoice, invoice: invoice}) do
    Invoice.changeset(invoice, stripe_invoice)
  end

  defp create_stripe_invoice(
         %{gallery: %{organization: %{user: user}}} = invoice_order,
         outstanding
       ) do
    Invoices.invoice_user(user, outstanding,
      description: "Outstanding fulfilment charges for order ##{Order.number(invoice_order)}"
    )
  end

  defp insert_invoice_changeset(%{stripe_invoice: stripe_invoice}, order),
    do: Invoices.changeset(stripe_invoice, order)
end
