defmodule Picsello.Cart.Checkouts do
  @moduledoc "context module for checking out a cart"

  alias Picsello.{
    Cart.Digital,
    Cart.Order,
    Cart.Product,
    Galleries,
    Intents,
    Invoices,
    Payments,
    Repo,
    WHCC
  }

  alias Picsello.WHCC.Order.Created, as: WHCCOrder

  import Picsello.Cart,
    only: [product_name: 1, product_quantity: 1, item_image_url: 1, preload_digitals: 1]

  import Ecto.Multi, only: [new: 0, run: 3, merge: 2, insert: 3, update: 3, append: 2]

  import Ecto.Query, only: [from: 2]
  import Money.Sigils

  @doc """
  1. contains products?
    1. create whcc order (needed for fee amount)
    1. outstanding whcc charges?
      1. create invoice
      1. client does not owe?
        1. finalize invoice
  1. client owes?
    1. create checkout session (with fee amount)
    1. insert intent
  1. client does not owe?
    1. place picsello order
  """

  @spec check_out(integer(), map()) ::
          {:ok, map()} | {:error, any(), any(), map()}
  def check_out(order_id, opts) do
    new()
    |> run(:cart, :load_cart, [order_id])
    |> run(:client_total, &client_total/2)
    |> merge(fn
      %{client_total: ~M[0]USD, cart: %{products: []} = cart} ->
        update(new(), :order, place_order(cart))

      %{cart: %{products: []} = cart} ->
        create_session(cart, opts)

      %{client_total: ~M[0]USD, cart: %{products: [_ | _]} = cart} ->
        new()
        |> append(create_whcc_order(cart))
        |> run(:stripe_invoice, &create_stripe_invoice/2)
        |> run(:finalize_invoice, &finalize_invoice/2)
        |> insert(:invoice, &insert_invoice/1)
        |> update(:order, place_order(cart))

      %{client_total: client_total, cart: %{products: [_ | _]} = cart} ->
        new()
        |> append(create_whcc_order(cart))
        |> merge(
          &create_session(
            cart,
            opts |> Map.merge(&1) |> Map.put(:client_total, client_total)
          )
        )
        |> merge(&handle_invoice/1)
    end)
    |> Repo.transaction()
  end

  def load_cart(repo, _multi, order_id) do
    from(order in Order,
      preload: [gallery: [organization: :user], products: :whcc_product],
      where: order.id == ^order_id and is_nil(order.placed_at)
    )
    |> preload_digitals()
    |> repo.one()
    |> case do
      nil -> {:error, :not_found}
      order -> {:ok, order}
    end
  end

  defp create_whcc_order(
         %Order{products: products, delivery_info: delivery_info, gallery_id: gallery_id} = order
       ) do
    editors =
      for product <- products do
        WHCC.Editor.Export.Editor.new(product.editor_id,
          order_attributes: WHCC.Shipping.to_attributes(product)
        )
      end

    account_id = Galleries.account_id(gallery_id)

    export =
      WHCC.editors_export(account_id, editors,
        entry_id: order |> Order.number() |> to_string(),
        address: delivery_info
      )

    new()
    |> run(:whcc_order, fn _, _ ->
      WHCC.create_order(account_id, export)
    end)
    |> update(:save_whcc_order, &Order.whcc_order_changeset(order, &1.whcc_order))
  end

  defp create_session(cart, %{whcc_order: whcc_order, client_total: client_total} = opts),
    do:
      create_session(
        cart,
        Enum.min_by(
          [client_total, WHCCOrder.total(whcc_order)],
          & &1.amount
        ),
        opts
      )

  defp create_session(cart, opts),
    do: create_session(cart, ~M[0]USD, opts)

  defp create_session(
         %{gallery: %{organization: %{stripe_account_id: stripe_account_id}}} = order,
         %{amount: application_fee_cents},
         %{"success_url" => success_url, "cancel_url" => cancel_url}
       ) do
    order_number = Order.number(order)

    params = %{
      line_items: build_line_items(order),
      customer_email: order.delivery_info.email,
      client_reference_id: "order_number_#{order_number}",
      payment_intent_data: %{
        application_fee_amount: application_fee_cents,
        capture_method: :manual
      },
      success_url: success_url,
      cancel_url: cancel_url
    }

    new()
    |> run(:session, fn _, _ ->
      Picsello.Payments.create_session(
        params,
        expand: [:payment_intent],
        connect_account: stripe_account_id
      )
    end)
    |> insert(:intent, fn %{session: %{payment_intent: intent}} ->
      Intents.changeset(intent, order)
    end)
  end

  defp handle_invoice(
         %{
           whcc_order: whcc_order,
           save_whcc_order: order,
           intent: %{application_fee_amount: application_fee_amount}
         } = state
       ) do
    whcc_order
    |> WHCCOrder.total()
    |> Money.subtract(application_fee_amount)
    |> case do
      ~M[0]USD ->
        new()

      outstanding ->
        new()
        |> run(:stripe_invoice, fn _, _ -> create_stripe_invoice(order, outstanding) end)
        |> insert(:invoice, &insert_invoice(Map.merge(state, &1)))
    end
  end

  defp create_stripe_invoice(
         _repo,
         %{save_whcc_order: %{whcc_order: whcc_order} = order}
       ),
       do: create_stripe_invoice(order, WHCCOrder.total(whcc_order))

  defp create_stripe_invoice(
         %{gallery: %{organization: %{user: user}}} = invoice_order,
         %{amount: outstanding_cents}
       ) do
    with "" <> customer <- Picsello.Subscriptions.user_customer_id(user),
         {:ok, _invoice_item} <-
           Payments.create_invoice_item(%{
             customer: customer,
             amount: outstanding_cents,
             currency: "USD"
           }),
         {:ok, invoice} <-
           Payments.create_invoice(%{
             customer: customer,
             description:
               "Outstanding fulfilment charges for order ##{Order.number(invoice_order)}",
             auto_advance: true
           }) do
      {:ok, invoice}
    end
  end

  defp insert_invoice(%{save_whcc_order: order, finalize_invoice: stripe_invoice}),
    do: Invoices.changeset(stripe_invoice, order)

  defp insert_invoice(%{save_whcc_order: order, stripe_invoice: stripe_invoice}),
    do: Invoices.changeset(stripe_invoice, order)

  defp finalize_invoice(_repo, %{stripe_invoice: stripe_invoice}),
    do: Picsello.Payments.finalize_invoice(stripe_invoice, %{auto_advance: true})

  defp place_order(cart), do: Order.placed_changeset(cart)
  defp client_total(_repo, %{cart: cart}), do: {:ok, Order.total_cost(cart)}

  defp build_line_items(%Order{digitals: digitals, products: products} = order) do
    for item <- Enum.concat([products, digitals, [order]]), reduce: [] do
      line_items ->
        case to_line_item(item) do
          %{
            image: image,
            name: name,
            price: price,
            tax: tax
          } ->
            [
              %{
                price_data: %{
                  currency: price.currency,
                  unit_amount: price.amount,
                  product_data: %{
                    name: name,
                    images: [item_image_url(image)],
                    tax_code: Picsello.Payments.tax_code(tax)
                  },
                  tax_behavior: "exclusive"
                },
                quantity: 1
              }
              | line_items
            ]

          _ ->
            line_items
        end
    end
    |> Enum.reverse()
  end

  defp to_line_item(%Digital{} = digital) do
    %{
      image: digital,
      name: "Digital image",
      price: Digital.charged_price(digital),
      tax: :digital
    }
  end

  defp to_line_item(%Product{} = product) do
    %{
      image: product,
      name: "#{product_name(product)} (Qty #{product_quantity(product)})",
      price: Product.charged_price(product),
      tax: :product
    }
  end

  defp to_line_item(%Order{bundle_price: %Money{}} = order) do
    %{
      price: order.bundle_price,
      tax: :digital,
      name: "Bundle - all digital downloads",
      image: {:bundle, order.gallery}
    }
  end

  defp to_line_item(%Order{}), do: nil

  defp run(multi, name, fun, args), do: Ecto.Multi.run(multi, name, __MODULE__, fun, args)
end
