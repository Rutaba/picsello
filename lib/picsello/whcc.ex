defmodule Picsello.WHCC do
  @moduledoc "WHCC context module"
  alias Picsello.{Repo, WHCC.Adapter}

  import Ecto.Query, only: [from: 2]

  def sync() do
    # fetch latest products from whcc api
    # upsert changes into db records
    # mark unmentioned products as deleted
    products = Adapter.products()

    Repo.transaction(fn ->
      categories = sync_categories(products)
      sync_products(products, categories)
    end)
  end

  defp sync_products(products, categories) do
    category_id_map =
      for(
        %{whcc_id: whcc_id, id: database_id} <- categories,
        do: {whcc_id, database_id},
        into: %{}
      )

    products
    |> Enum.map(&Adapter.product_details/1)
    |> sync_table(
      Picsello.Product,
      fn %{
           category: %{id: category_id},
           attribute_categories: attribute_categories
         } ->
        %{
          category_id: Map.get(category_id_map, category_id),
          attribute_categories: attribute_categories
        }
      end,
      [:category_id, :attribute_categories]
    )
  end

  defp sync_categories(products) do
    products
    |> Enum.map(&Map.get(&1, :category))
    |> Enum.uniq()
    |> sync_table(Picsello.Category, fn %{name: name} -> %{name: name, icon: "book"} end)
  end

  defp sync_table(rows, schema, to_row, replace_fields \\ []) do
    updated_at = DateTime.truncate(DateTime.utc_now(), :second)

    rows =
      for({%{id: id, name: name} = row, position} <- Enum.with_index(rows)) do
        row
        |> to_row.()
        |> Enum.into(%{
          whcc_id: id,
          whcc_name: name,
          deleted_at: nil,
          position: position,
          updated_at: updated_at
        })
      end

    schema.active()
    |> Repo.update_all(set: [deleted_at: DateTime.utc_now()])

    {_number, records} =
      Repo.insert_all(schema, rows,
        conflict_target: [:whcc_id],
        on_conflict: {:replace, replace_fields ++ [:whcc_name, :deleted_at, :updated_at]},
        returning: true
      )

    records
  end

  def categories, do: Repo.all(categories_query())

  def category(id) do
    products =
      Picsello.Product.active()
      |> Picsello.Product.with_attributes()

    from(category in categories_query(), preload: [products: ^products]) |> Repo.get!(id)
  end

  defp categories_query(),
    do:
      from(category in Picsello.Category.active(),
        where: not category.hidden,
        order_by: [asc: category.position]
      )

  def variations(%Picsello.Product{attributes: attributes}) do
    for {%{
           "variation_id" => id,
           "variation_name" => name,
           "price" => price,
           "category_name" => category_name,
           "attribute_name" => attribute_name,
           "attribute_id" => attribute_id
         }, i} <- Enum.with_index(attributes),
        reduce: %{} do
      acc ->
        attribute = %{
          price: Money.new(trunc(price * 100)),
          id: attribute_id,
          name: attribute_name,
          category_name: category_name,
          position: i
        }

        Map.update(
          acc,
          %{id: id, name: name},
          [attribute],
          &[attribute | &1]
        )
    end
    |> Enum.map(&Map.put(elem(&1, 0), :attributes, &1 |> elem(1) |> Enum.reverse()))
    |> Enum.sort_by(&(&1 |> Map.get(:attributes) |> hd |> Map.get(:position)))
  end
end
