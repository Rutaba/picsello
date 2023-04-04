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
    WHCC,
    OrganizationCard
  }

  alias Picsello.WHCC.Order.Created, as: WHCCOrder
  alias WHCC.Editor.Export.Editor

  import Picsello.Cart,
    only: [product_name: 1, product_quantity: 1, item_image_url: 1, preload_digitals: 1]

  import Ecto.Multi, only: [new: 0, run: 3, merge: 2, insert: 3, update: 3, append: 2, put: 3]

  import Ecto.Query, only: [from: 2]
  import Money.Sigils

  @doc """
  1. order already has a session?
      1. expire session
      2. update intent
  1. contains products?
      1. create whcc order (needed for fee amount)
      2. outstanding whcc charges?
          2. client does not owe?
              1. create invoice
              2. finalize invoice
  2. client owes?
      2. create checkout session (with fee amount)
      3. insert intent
  3. client does not owe?
      1. place picsello order
  """

  @spec check_out(integer(), map()) ::
          {:ok, map()} | {:error, any(), any(), map()}
  def check_out(order_id, opts) do
    order_id
    |> handle_previous_session()
    |> append(
      new()
      |> run(:cart, :load_cart, [order_id])
      |> run(:client_total, &client_total/2)
      |> merge(fn
        %{client_total: ~M[0]USD, cart: %{products: []} = cart} ->
          new()
          |> update(:order, place_order(cart))
          |> run(:insert_card, fn _repo, %{order: order} ->
            OrganizationCard.insert_for_proofing_order(order)
          end)

        %{cart: %{products: []} = cart} ->
          create_session(cart, opts)

        %{client_total: ~M[0]USD, cart: %{products: [_ | _]} = cart} ->
          new()
          |> append(create_whcc_order(cart))
          |> run(:stripe_invoice, &create_stripe_invoice/2)
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
      end)
    )
    |> Repo.transaction()
  end

  def handle_previous_session(order_id) do
    new()
    |> merge(fn _ ->
      case load_previous_intent(order_id) do
        nil ->
          new()

        intent ->
          new()
          |> put(:previous_intent, intent)
          |> run(:previous_stripe_intent, &fetch_previous_stripe_intent/2)
          |> run(:expire_previous_session, &expire_previous_session/2)
          |> update(:updated_previous_intent, &update_previous_intent/1)
      end
    end)
  end

  defp load_previous_intent(order_id),
    do:
      from(intent in Intents.unresolved_for_order(order_id),
        join: order in assoc(intent, :order),
        join: gallery in assoc(order, :gallery),
        join: organization in assoc(gallery, :organization),
        preload: [order: {order, [gallery: {gallery, [organization: organization]}]}]
      )
      |> Repo.one()

  defp expire_previous_session(_repo, %{previous_stripe_intent: %{status: "canceled"} = intent}) do
    {:ok, %{payment_intent: intent}}
  end

  defp expire_previous_session(_repo, %{
         previous_intent: %{
           stripe_session_id: id,
           order: %{gallery: %{organization: %{stripe_account_id: connect_account}}}
         }
       }) do
    Payments.expire_session(id, connect_account: connect_account, expand: [:payment_intent])
    |> case do
      {:ok, %{status: "expired", payment_intent: intent} = session} ->
        {:ok, %{session | payment_intent: %{intent | status: "canceled"}}}

      error ->
        error
    end
  end

  defp update_previous_intent(%{
         previous_intent: intent,
         expire_previous_session: %{payment_intent: stripe_intent}
       }) do
    Intents.changeset(intent, stripe_intent)
  end

  def load_cart(repo, _multi, order_id) do
    from(order in Order,
      join: gallery in assoc(order, :gallery),
      join: organization in assoc(gallery, :organization),
      join: user in assoc(organization, :user),
      preload: [
        gallery: {gallery, [organization: {organization, [user: user]}]},
        products: :whcc_product
      ],
      where: order.id == ^order_id and is_nil(order.placed_at)
    )
    |> preload_digitals()
    |> repo.one()
    |> case do
      nil -> {:error, :not_found}
      order -> {:ok, order}
    end
  end

  defp create_whcc_order(%Order{delivery_info: delivery_info, gallery_id: gallery_id} = order) do
    editors =
      order
      |> Picsello.Cart.Order.lines_by_product()
      |> Enum.reduce([], &editors(&1, &2))

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

  defp editors({_whcc_product, line_items}, acc) do
    product = Enum.find(line_items, & &1.shipping_upcharge)
    order_attributes = WHCC.Shipping.attributes(product)

    acc ++ Enum.map(line_items, &Editor.new(&1.editor_id, order_attributes: order_attributes))
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
      shipping_options: shipping_options(order) |> IO.inspect(),
      success_url: success_url,
      billing_address_collection: "auto",
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
    |> insert(:intent, fn %{session: %{id: session_id, payment_intent: intent}} ->
      Intents.changeset(intent, order_id: order.id, session_id: session_id)
    end)
  end

  alias Picsello.Cart

  defp shipping_options(%{products: [_ | _] = products}) do
    products = Enum.filter(products, & &1.shipping_type)
    shipping = Cart.total_shipping(products)
    {min, max} = Cart.shipping_days(products)

    [
      %{
        shipping_rate_data: %{
          type: "fixed_amount",
          fixed_amount: %{
            amount: shipping.amount,
            currency: shipping.currency
          },
          delivery_estimate: %{
            minimum: %{unit: "day", value: min},
            maximum: %{unit: "day", value: max}
          },
          display_name: "Estimate Delivery"
        }
      }
    ]
  end

  defp shipping_options(%{products: []}), do: []

  defp create_stripe_invoice(
         _repo,
         %{save_whcc_order: %{whcc_order: whcc_order} = order}
       ),
       do: create_stripe_invoice(order, WHCCOrder.total(whcc_order))

  defp create_stripe_invoice(
         %{gallery: %{organization: %{user: user}}} = invoice_order,
         outstanding
       ) do
    Invoices.invoice_user(user, outstanding,
      description: "Outstanding fulfilment charges for order ##{Order.number(invoice_order)}"
    )
  end

  defp insert_invoice(%{save_whcc_order: order, stripe_invoice: stripe_invoice}),
    do: Invoices.changeset(stripe_invoice, order)

  defp place_order(cart), do: Order.placed_changeset(cart)
  defp client_total(_repo, %{cart: cart}), do: {:ok, Order.total_cost(cart)}

  defp fetch_previous_stripe_intent(
         _repo,
         %{
           previous_intent: %{
             stripe_payment_intent_id: id,
             order: %{gallery: %{organization: %{stripe_account_id: stripe_account_id}}}
           }
         }
       ),
       do: Payments.retrieve_payment_intent(id, connect_account: stripe_account_id)

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
      tax: :product,
      total_markuped_price: product.total_markuped_price
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
