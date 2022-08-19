defmodule Picsello.WHCC.Sync do
  @moduledoc """
    Pulls the latest designs and products from WHCC and stores them
    in `Picsello.Design`, `Picsello.Category`, and `Picsello.Product`.

    Marks those no longer in the WHCC response with `deleted_at`.
  """

  alias Picsello.{Repo, WHCC.Adapter}

  @doc """
    fetch latest from whcc api
    upsert changes into db records
    mark unmentioned as deleted
  """
  def sync() do
    products = async_stream(Adapter.products(), &Adapter.product_details/1)
    designs = async_stream(Adapter.designs(), &Adapter.design_details/1)

    Repo.transaction(
      fn ->
        categories = sync_categories(products)
        products = sync_products(products, categories)
        sync_designs(designs, products)

        Ecto.Adapters.SQL.query!(Repo, "refresh materialized view product_attributes")
      end,
      timeout: :infinity
    )

    :ok
  end

  defp sync_products(products, categories) do
    category_id_map =
      for(
        %{whcc_id: whcc_id, id: database_id} <- categories,
        do: {whcc_id, database_id},
        into: %{}
      )

    products
    |> sync_table(
      Picsello.Product,
      fn %{
           category: %{id: category_id},
           attribute_categories: attribute_categories,
           api: api
         } ->
        %{
          category_id: Map.get(category_id_map, category_id),
          attribute_categories: attribute_categories,
          api: api
        }
      end,
      [:category_id, :attribute_categories, :api]
    )
  end

  defp sync_designs(designs, products) do
    product_id_map =
      for(
        %{whcc_id: whcc_id, id: database_id} <- products,
        do: {whcc_id, database_id},
        into: %{}
      )

    designs
    |> sync_table(
      Picsello.Design,
      fn %{
           product_id: product_id,
           attribute_categories: attribute_categories,
           api: api
         } ->
        %{
          product_id: Map.get(product_id_map, product_id),
          attribute_categories: attribute_categories,
          api: api
        }
      end,
      [:product_id, :attribute_categories, :api]
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

  defp async_stream(enum, f) do
    enum
    |> Task.async_stream(f)
    |> Stream.map(fn {:ok, value} -> value end)
  end
end
