defmodule Picsello.WHCC do
  @moduledoc "WHCC context module"
  alias Picsello.{Repo, WHCC.Adapter}

  import Ecto.Query

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

  def categories do
    from(category in Picsello.Category.active(),
      where: not category.hidden,
      order_by: [asc: category.position]
    )
    |> Repo.all()
  end
end
