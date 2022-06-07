defmodule Picsello.Cart.Checkouts do
  @moduledoc "context module for checking out a cart"

  alias Picsello.{Repo, Intents, Cart.Order, Cart.Product, Cart.Digital, WHCC, Galleries}

  import Picsello.Cart,
    only: [product_name: 1, product_quantity: 1, item_image_url: 1, preload_digitals: 1]

  import Ecto.Multi, only: [new: 0, run: 3, merge: 2, insert: 3, update: 3, put: 3]

  import Ecto.Query, only: [from: 2]

  def check_out(order_id, opts) do
    new()
    |> run(:load_cart, :load_cart, [order_id])
    |> merge(fn %{load_cart: cart} ->
      multi = put(new(), :cart, cart)

      if cart |> Order.total_cost() |> Money.zero?() do
        multi
      else
        multi
        |> run(:session, :create_session, [opts])
        |> insert(:intent, &insert_intent/1)
      end
    end)
    |> update(:place_order, &place_order/1)
    |> merge(fn %{place_order: order} ->
      multi = put(new(), :order, order)

      case order do
        %{products: []} ->
          multi

        _ ->
          multi
          |> run(:whcc_order, &create_whcc_order/2)
          |> update(:save_whcc_order, &save_whcc_order/1)
      end
    end)
    |> Repo.transaction()
  end

  def load_cart(repo, _multi, order_id) do
    from(order in Order,
      preload: [gallery: :organization, products: :whcc_product],
      where: order.id == ^order_id and is_nil(order.placed_at)
    )
    |> preload_digitals()
    |> repo.one()
    |> case do
      nil -> {:error, :not_found}
      order -> {:ok, order}
    end
  end

  defp place_order(%{cart: order}), do: Order.placed_changeset(order)

  def create_session(
        _repo,
        %{cart: %{gallery: gallery, digitals: digitals, products: products} = order},
        opts
      ) do
    {%{"success_url" => success_url, "cancel_url" => cancel_url}, opts} =
      Map.split(opts, ~w[success_url cancel_url])

    line_items =
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

    %{organization: %{stripe_account_id: stripe_account_id}} = gallery

    order_number = Order.number(order)

    params =
      Enum.into(opts, %{
        line_items: line_items,
        customer_email: order.delivery_info.email,
        client_reference_id: "order_number_#{order_number}",
        payment_intent_data: %{capture_method: :manual},
        success_url: success_url,
        cancel_url: cancel_url
      })

    Picsello.Payments.create_session(
      params,
      opts
      |> Map.merge(%{expand: [:payment_intent], connect_account: stripe_account_id})
      |> Map.to_list()
    )
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

  defp insert_intent(%{cart: order, session: %{payment_intent: intent}}) do
    Intents.changeset(intent, order)
  end

  defp run(multi, name, fun, args), do: Ecto.Multi.run(multi, name, __MODULE__, fun, args)

  def create_whcc_order(_repo, %{
        order:
          %Order{products: products, delivery_info: delivery_info, gallery_id: gallery_id} = order
      }) do
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

    WHCC.create_order(account_id, export)
  end

  defp save_whcc_order(%{order: order, whcc_order: whcc_order}),
    do: Order.whcc_order_changeset(order, whcc_order)
end
