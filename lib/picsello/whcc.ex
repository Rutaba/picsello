defmodule Picsello.WHCC do
  @moduledoc "WHCC context module"
  import Ecto.Query, only: [from: 2]
  alias Picsello.{Repo, WHCC.Adapter, WHCC.Editor.Params}

  def sync() do
    # fetch latest from whcc api
    # upsert changes into db records
    # mark unmentioned as deleted
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

  def categories, do: Repo.all(categories_query())

  def preload_products(ids, user) do
    Picsello.Product.active()
    |> Picsello.Product.with_attributes(user)
    |> Ecto.Query.where([product], product.id in ^ids)
    |> Repo.all()
    |> Enum.map(&{&1.id, %{&1 | variations: variations(&1)}})
    |> Map.new()
  end

  def category(id) do
    products =
      Picsello.Product.active()
      |> Ecto.Query.select([product], struct(product, [:whcc_name, :id]))

    from(category in categories_query(), preload: [products: ^products]) |> Repo.get!(id)
  end

  def create_editor(
        %Picsello.Product{} = product,
        %Picsello.Galleries.Photo{} = photo,
        opts \\ []
      ) do
    product
    |> Params.build(photo, opts)
    |> Adapter.editor()
  end

  defdelegate editor_details(account_id, editor_id), to: Adapter
  defdelegate editor_export(account_id, editor_id), to: Adapter
  defdelegate create_order(account_id, editor_id, opts), to: Adapter
  defdelegate confirm_order(account_id, confirmation), to: Adapter

  def mark_up_price(_details, %{"totalOrderBasePrice" => base_price, "code" => "USD"}) do
    (base_price * 100)
    |> trunc()
    |> Money.new(:USD)
    |> Money.multiply(2)
  end

  defp variations(%{variations: variations}),
    do:
      for(
        variation <- variations,
        do:
          for(
            k <- ~w(id name attributes)a,
            do: {k, variation[Atom.to_string(k)]},
            into: %{}
          )
          |> Map.update!(
            :attributes,
            &for(
              attribute <- &1,
              do:
                for(
                  k <-
                    ~w(category_name category_id id name price markup)a,
                  do: {k, attribute[Atom.to_string(k)]},
                  into: %{}
                )
                |> Map.update!(:price, fn dolars -> Money.new(dolars) end)
            )
          )
      )

  defp categories_query(),
    do:
      from(category in Picsello.Category.active(),
        where: not category.hidden,
        order_by: [asc: category.position]
      )

  defp async_stream(enum, f) do
    enum
    |> Task.async_stream(f)
    |> Enum.to_list()
    |> Keyword.get_values(:ok)
  end
end
