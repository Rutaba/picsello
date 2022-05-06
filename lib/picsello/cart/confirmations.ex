defmodule Picsello.Cart.Confirmations do
  @moduledoc "context module for confirming orders. Should be accessed through Cart."

  alias Picsello.{Galleries, Cart.Order, Payments, Cart.OrderNumber, WHCC, Repo}
  import Ecto.Query, only: [from: 2]

  @doc """
  Confirms the order.

  1. query for order and connect account
  1. make sure the order isn't already confirmed
  1. maybe fetch the session
  1. verify the captured amount still matches the cart amount
  1. confirm the whcc orders
  1. mark the order as confirmed in our database
  1. capture the stripe funds
  """
  def confirm_order(
        %Stripe.Session{client_reference_id: "order_number_" <> order_number} = session,
        helpers
      ) do
    do_confirm_order(order_number, &Ecto.Multi.put(&1, :session, session), helpers)
  end

  def confirm_order(order_number, stripe_session_id, helpers) do
    do_confirm_order(
      order_number,
      &Ecto.Multi.run(&1, :session, __MODULE__, :fetch_session, [stripe_session_id]),
      helpers
    )
  end

  defp do_confirm_order(order_number, session_fn, helpers) do
    Ecto.Multi.new()
    |> Ecto.Multi.put(:order_number, order_number)
    |> Ecto.Multi.run(:order, &load_order/2)
    |> Ecto.Multi.run(:stripe_options, &stripe_options/2)
    |> Ecto.Multi.run(:confirmed, &check_confirmed/2)
    |> session_fn.()
    |> Ecto.Multi.run(:intent, &verify_intent/2)
    |> Ecto.Multi.update(:confirmed_order, &confirm_order_changeset/1)
    |> Ecto.Multi.run(:capture, &capture/2)
    |> Repo.transaction()
    |> case do
      {:error, :confirmed, true, %{order: order}} ->
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
        preload: [digitals: :photo, gallery: [job: [client: :organization]]]
      )
      |> repo.one!()
      |> Picsello.Cart.preload_products()

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

  defp check_confirmed(_, %{order: order}) do
    case order.placed_at do
      nil ->
        {:ok, false}

      %DateTime{} ->
        {:error, true}
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

  defp verify_intent(_, %{
         session: %{payment_intent: intent_id},
         order: order,
         stripe_options: stripe_options
       }) do
    %{amount: total} = Order.total_cost(order)

    case Payments.retrieve_payment_intent(intent_id, stripe_options) do
      {:ok, %{amount_capturable: ^total} = intent} ->
        {:ok, intent}

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
             placed_at: nil,
             products: [_ | _],
             whcc_order: %{confirmation_id: confirmation_id}
           } = order
       }) do
    {:ok, confirmation_result} =
      gallery |> Galleries.account_id() |> WHCC.confirm_order(confirmation_id)

    confirmed_products =
      for %{line_item: product, price: charged_price} <- Order.priced_lines(order) do
        %{product | charged_price: charged_price}
      end

    Order.confirmation_changeset(order, confirmation_result, confirmed_products)
  end

  defp confirm_order_changeset(%{
         order:
           %Order{
             products: [],
             digitals: digitals,
             placed_at: nil,
             whcc_order: nil,
             bundle_price: bundle_price
           } = order
       })
       when digitals != [] or not is_nil(bundle_price),
       do: Order.confirmation_changeset(order)

  defp capture(_repo, %{intent: %{id: intent_id}, stripe_options: stripe_options}) do
    case Payments.capture_payment_intent(intent_id, stripe_options) do
      {:ok, %{status: "succeeded"} = intent} ->
        {:ok, intent}

      {:ok, intent} ->
        {:error, "unexpected intent status:\n#{inspect(intent)}"}

      error ->
        error
    end
  end

  defp send_confirmation_email(order, helpers) do
    Picsello.Notifiers.ClientNotifier.deliver_order_confirmation(order, helpers)
  end
end
