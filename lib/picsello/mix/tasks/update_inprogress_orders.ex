defmodule Mix.Tasks.UpdateInprogressOrders do
  @moduledoc false

  use Mix.Task

  alias Picsello.{Repo, Cart, Cart.Order, Cart.Product, Intents.Intent}
  alias Ecto.{Multi, Changeset}

  import Ecto.Query

  @shortdoc "add shipping upchrage"

  @shipping_type "economy"
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
    |> Enum.reduce(Multi.new(), fn %{id: id} = order, multi ->
      order
      |> Cart.lines_by_product()
      |> Enum.reduce(multi, &products_multi(&2, &1))
      |> Multi.update(
        "#{id}-whcc-order",
        order
        |> Changeset.cast(%{whcc_order: nil}, [])
        |> Changeset.cast_embed(:whcc_order)
      )
      |> Multi.delete_all("#{id}-intents", from(i in Intent, where: i.order_id == ^id))
    end)
    |> Repo.transaction()
    |> tap(fn {:ok, _} = x -> x end)
  end

  defp products_multi(multi, {_whcc_product, line_items}) do
    line_items
    |> Enum.with_index(1)
    |> Enum.reduce(multi, fn
      {product, 1}, multi ->
        product
        |> Picsello.Cart.shipping_details(@shipping_type)
        |> update_product(product, multi)

      {product, _}, multi ->
        update_product(%{shipping_price: nil, shipping_upcharge: nil}, product, multi)
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
