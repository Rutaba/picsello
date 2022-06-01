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

  import Ecto.Multi, only: [new: 0, run: 3, merge: 2, insert: 3, update: 3, put: 3]

  import Ecto.Query, only: [from: 2]
  import Money.Sigils

  @doc """
  1. client owes?
    1. create checkout session
    1. insert intent
  1. place order
  1. contains products?
    1. create whcc order
    1. outstanding whcc charges?
      1. create invoice
      1. client does not owe?
        1. finalize invoice
  """
  def check_out(order_id, opts) do
    new()
    |> run(:cart, :load_cart, [order_id])
    |> run(:client_total, &client_total/2)
    |> merge(fn
      %{client_total: ~M[0]USD} ->
        new()

      %{cart: cart} ->
        new()
        |> put({:cart, :session}, cart)
        |> run(:session, :create_session, [opts])
        |> insert(:intent, &insert_intent/1)
    end)
    |> update(:order, &place_order/1)
    |> merge(fn
      %{order: %{products: []}} ->
        new()

      %{order: order, client_total: client_total} ->
        new()
        |> put({:order, :products}, order)
        |> run(:whcc_order, &create_whcc_order/2)
        |> update(:save_whcc_order, &save_whcc_order/1)
        |> merge(fn %{:whcc_order => whcc_order, {:order, :products} => order} ->
          case outstanding(client_total, whcc_order) do
            ~M[0]USD ->
              new()

            outstanding ->
              new()
              |> put({:order, :invoice}, order)
              |> put(:outstanding, outstanding)
              |> run(:stripe_invoice, &create_stripe_invoice/2)
              |> insert(:invoice, &insert_invoice/1)
              |> merge(fn
                %{invoice: invoice, stripe_invoice: stripe_invoice}
                when client_total == ~M[0]USD ->
                  new()
                  |> put({:invoice, :finalize}, invoice)
                  |> put({:stripe_invoice, :finalize}, stripe_invoice)
                  |> run(:finalize_invoice, &finalize_invoice/2)
                  |> update(:update_invoice, &update_invoice/1)

                _ ->
                  new()
              end)
          end
        end)
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

  defp create_stripe_invoice(_repo, %{
         :outstanding => %{amount: outstanding_cents},
         {:order, :invoice} => %{gallery: gallery} = invoice_order
       }) do
    %{stripe_customer_id: customer} = Galleries.gallery_photographer(gallery)

    with {:ok, _invoice_item} <-
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

  defp insert_invoice(%{:stripe_invoice => stripe_invoice, {:order, :invoice} => order}),
    do: Invoices.changeset(stripe_invoice, order)

  defp finalize_invoice(_repo, %{{:stripe_invoice, :finalize} => stripe_invoice}) do
    Picsello.Payments.finalize_invoice(stripe_invoice, %{auto_advance: true})
  end

  defp update_invoice(%{:finalize_invoice => stripe_invoice, {:invoice, :finalize} => invoice}),
    do: Invoices.changeset(invoice, stripe_invoice)

  defp place_order(%{cart: order}), do: Order.placed_changeset(order)
  defp client_total(_repo, %{cart: cart}), do: {:ok, Order.total_cost(cart)}

  defp outstanding(client_total, whcc_order) do
    Enum.min(
      [Money.subtract(client_total, WHCCOrder.total(whcc_order)), ~M[0]USD],
      &(Money.cmp(&1, &2) != :gt)
    )
    |> Money.neg()
  end

  def create_session(
        _repo,
        %{
          {:cart, :session} => %{gallery: gallery, digitals: digitals, products: products} = order
        },
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

  defp insert_intent(%{{:cart, :session} => order, :session => %{payment_intent: intent}}) do
    Intents.changeset(intent, order)
  end

  defp run(multi, name, fun, args), do: Ecto.Multi.run(multi, name, __MODULE__, fun, args)

  def create_whcc_order(_repo, %{
        {:order, :products} =>
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

  defp save_whcc_order(%{{:order, :products} => order, :whcc_order => whcc_order}),
    do: Order.whcc_order_changeset(order, whcc_order)
end
