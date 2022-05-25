defmodule Picsello.Cart.Checkouts do
  @moduledoc "context module for checking out a cart"

  alias Picsello.{Repo, Cart.Order, Cart.Product, Cart.Digital, WHCC, Galleries}
  import Picsello.Cart, only: [product_name: 1, product_quantity: 1, item_image_url: 1]

  def create_whcc_order(
        %Order{
          products: products,
          delivery_info: delivery_info,
          gallery_id: gallery_id
        } = order
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

    order
    |> Order.whcc_order_changeset(WHCC.create_order(account_id, export))
    |> Repo.update!()
  end

  def create_session(%{gallery: gallery, digitals: digitals, products: products} = order, opts)
      when is_list(digitals) and is_list(products) do
    product_line_items =
      for line_item <- products do
        price = Product.charged_price(line_item)

        %{
          price_data: %{
            currency: price.currency,
            unit_amount: price.amount,
            product_data: %{
              name: "#{product_name(line_item)} (Qty #{product_quantity(line_item)})",
              images: [item_image_url(line_item)],
              tax_code: Picsello.Payments.tax_code(:product)
            },
            tax_behavior: "exclusive"
          },
          quantity: 1
        }
      end

    digital_line_items =
      Enum.map(digitals, fn digital ->
        price = Digital.charged_price(digital)

        %{
          price_data: %{
            currency: price.currency,
            unit_amount: price.amount,
            product_data: %{
              name: "Digital image",
              images: [item_image_url(digital)],
              tax_code: Picsello.Payments.tax_code(:digital)
            },
            tax_behavior: "exclusive"
          },
          quantity: 1
        }
      end)

    bundle_line_items =
      if order.bundle_price do
        %{gallery: gallery} = order

        [
          %{
            price_data: %{
              currency: order.bundle_price.currency,
              unit_amount: order.bundle_price.amount,
              product_data: %{
                name: "Bundle - all digital downloads",
                images: [item_image_url({:bundle, gallery})],
                tax_code: Picsello.Payments.tax_code(:digital)
              },
              tax_behavior: "exclusive"
            },
            quantity: 1
          }
        ]
      else
        []
      end

    {%{"success_url" => success_url, "cancel_url" => cancel_url}, opts} =
      Map.split(opts, ~w[success_url cancel_url])

    params =
      Enum.into(opts, %{
        line_items: product_line_items ++ digital_line_items ++ bundle_line_items,
        customer_email: order.delivery_info.email,
        client_reference_id: "order_number_#{Order.number(order)}",
        payment_intent_data: %{capture_method: :manual},
        success_url: success_url,
        cancel_url: cancel_url
      })

    %{organization: %{stripe_account_id: stripe_account_id}} = gallery

    Picsello.Payments.create_session(params, Map.put(opts, :connect_account, stripe_account_id))
  end
end
