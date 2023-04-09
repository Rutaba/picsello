defmodule Mix.Tasks.UpdateInprogressOrders do
  @moduledoc false

  use Mix.Task

  alias Picsello.{Repo, Category, Cart, Galleries, WHCC, Cart.Order, Cart.Product, Intents.Intent}
  alias Ecto.{Multi, Changeset}

  import Ecto.Query

  @shipping_type "economy"
  @shipping_to_all Category.shipping_all_whcc_ids()

  @shortdoc "add shipping upchrage"
  def run(_) do
    load_app()

    orders =
      from(o in Order,
        join: p in assoc(o, :products),
        where: is_nil(o.placed_at),
        group_by: o.id,
        preload: [products: :whcc_product]
      )
      |> Repo.all()

    orders
    |> Task.async_stream(
      fn %{id: id, gallery_id: gallery_id} = order ->
        order
        |> Cart.lines_by_product()
        |> Enum.reduce(Multi.new(), &products_multi(&2, &1, gallery_id))
        |> Multi.update(
          "#{id}-whcc-order",
          order
          |> Changeset.cast(%{whcc_order: nil}, [])
          |> Changeset.cast_embed(:whcc_order)
        )
        |> Multi.delete_all("#{id}-intents", from(i in Intent, where: i.order_id == ^id))
      end,
      timeout: 10_000
    )
    |> Enum.reduce(Multi.new(), fn {:ok, multi}, acc_multi ->
      Multi.merge(acc_multi, fn _ -> multi end)
    end)
    |> Repo.transaction()
    |> tap(fn {:ok, _} = x -> x end)
  end

  defp products_multi(multi, {%{category: %{whcc_id: whcc_id}}, line_items}, gallery_id) do
    line_items
    |> Enum.reverse()
    |> Enum.with_index(1)
    |> Enum.reduce(multi, fn
      {%{editor_id: editor_id} = product, i}, multi when i == 1 or whcc_id in @shipping_to_all ->
        account_id = Galleries.account_id(gallery_id)
        %{total_markuped_price: price} = WHCC.get_item_attrs(account_id, editor_id)

        product
        |> Cart.shipping_details(@shipping_type)
        |> Map.put(:total_markuped_price, price)
        |> update_product(product, multi)

      {product, _}, multi ->
        details = %{shipping_base_charge: nil, shipping_upcharge: nil, shipping_type: nil}
        update_product(details, product, multi)
    end)
  end

  defp update_product(details, %{print_credit_discount: credit} = product, multi) do
    price = Product.price(product)

    multi
    |> Multi.update(
      "#{product.id}-product",
      Product.changeset(
        product,
        details
        |> Map.put(:price, price)
        |> Map.put(:volume_discount, Money.new(0))
        |> Map.put(:print_credit_discount, print_credit_discount(credit, price))
      )
    )
  end

  defp print_credit_discount(credit, price) do
    case Money.cmp(credit, price) do
      :lt -> credit
      _ -> price
    end
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
