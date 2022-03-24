defmodule Picsello.Cart.Confirmations do
  @moduledoc "context module for confirming orders. Should be accessed through Cart."

  alias Picsello.{Galleries, Cart.Order, Payments, Cart.CartProduct, Cart.OrderNumber, WHCC, Repo}
  alias Galleries.Gallery
  import Ecto.Query, only: [from: 2, preload: 2]

  @doc """
  Confirms the order.
  """
  def confirm_order(
        %Stripe.Session{
          client_reference_id: "order_number_" <> order_number
        } = session
      ) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:order, fn repo, _ ->
      order =
        order_number
        |> order_numbered()
        |> preload(gallery: [job: [client: :organization]])
        |> repo.one!()

      {:ok, order}
    end)
    |> Ecto.Multi.append(ensure_unconfirmed_multi())
    |> Ecto.Multi.append(stripe_options_multi())
    |> Ecto.Multi.run(:session, fn _, _ -> {:ok, session} end)
    |> Ecto.Multi.append(verify_intent_and_confirm_order_multi())
    |> commit_confirm_order()
  end

  def(
    confirm_order(
      %Gallery{id: gallery_id},
      order_number,
      stripe_session_id
    )
  ) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:order, fn repo, _ ->
      order =
        from(order in order_numbered(order_number),
          join: gallery in assoc(order, :gallery),
          where: gallery.id == ^gallery_id,
          preload: [gallery: {gallery, job: [client: :organization]}]
        )
        |> repo.one!()

      {:ok, order}
    end)
    |> Ecto.Multi.append(ensure_unconfirmed_multi())
    |> Ecto.Multi.append(stripe_options_multi())
    |> Ecto.Multi.run(:session, fn _,
                                   %{
                                     stripe_options: stripe_options
                                   } ->
      case Payments.retrieve_session(stripe_session_id, stripe_options) do
        {:ok,
         %{payment_status: "unpaid", client_reference_id: "order_number_" <> ^order_number} =
             session} ->
          {:ok, session}

        {:ok, session} ->
          {:error, "unexpected session #{inspect(session)}"}

        error ->
          error
      end
    end)
    |> Ecto.Multi.append(verify_intent_and_confirm_order_multi())
    |> commit_confirm_order()
  end

  defp confirmed?(%Order{placed_at: %DateTime{}}), do: true
  defp confirmed?(%Order{}), do: false

  defp ensure_unconfirmed_multi,
    do:
      Ecto.Multi.new()
      |> Ecto.Multi.run(:confirmed, fn _, %{order: order} ->
        if confirmed?(order), do: {:error, true}, else: {:ok, false}
      end)

  defp stripe_options_multi,
    do:
      Ecto.Multi.run(Ecto.Multi.new(), :stripe_options, fn _, %{order: order} ->
        case order do
          %{gallery: %{job: %{client: %{organization: %{stripe_account_id: stripe_account_id}}}}} ->
            {:ok, connect_account: stripe_account_id}

          _ ->
            {:error, "no connect account"}
        end
      end)

  defp verify_intent_and_confirm_order_multi,
    do:
      Ecto.Multi.new()
      |> Ecto.Multi.run(:intent, fn _,
                                    %{
                                      session: %{payment_intent: intent_id},
                                      order: order,
                                      stripe_options: stripe_options
                                    } ->
        %{amount: total} = Order.total(order)

        with {:ok, %{amount_capturable: ^total}} <-
               Payments.retrieve_payment_intent(intent_id, stripe_options),
             {:ok, %{status: "succeeded"} = intent} <-
               Payments.capture_payment_intent(intent_id, stripe_options) do
          {:ok, intent}
        else
          error ->
            error =
              ["error:", inspect(error), "order:", inspect(order)]
              |> Enum.join("\n")

            {:error, error}
        end
      end)
      |> Ecto.Multi.update(:confirm, fn %{order: order} ->
        confirm_order_changeset(order)
      end)

  defp confirm_order_changeset(
         %Order{products: products, gallery: gallery, placed_at: nil} = order
       ) do
    confirmed_products =
      products
      |> Task.async_stream(fn %CartProduct{whcc_order: %{confirmation: confirmation}} = product ->
        confirmation = gallery |> Galleries.account_id() |> WHCC.confirm_order(confirmation)

        CartProduct.add_confirmation(product, confirmation)
      end)
      |> Enum.map(fn {:ok, product} -> product end)

    Order.confirmation_changeset(order, confirmed_products)
  end

  defp commit_confirm_order(%Ecto.Multi{} = multi) do
    case Repo.transaction(multi) do
      {:error, :confirmed, true, %{order: order}} ->
        {:ok, order}

      {:ok, %{order: order}} ->
        {:ok, order}

      {:error, _, _, %{session: %{payment_intent: intent_id}, stripe_options: stripe_options}} =
          error ->
        Payments.cancel_payment_intent(intent_id, stripe_options)
        error

      other ->
        other
    end
  end

  defp order_numbered(order_number) do
    order_id = OrderNumber.from_number(order_number)
    from(order in Order, where: order.id == ^order_id)
  end
end
