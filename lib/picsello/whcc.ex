defmodule Picsello.WHCC do
  @moduledoc "WHCC context module"

  # extracted from https://docs.google.com/spreadsheets/d/19epUUDsDmHWNePViH9v8x5BXGp0Anu0x/edit#gid=1549535757
  @area_markups [
    {24, 25},
    {35, 35},
    {80, 75},
    {96, 75},
    {100, 75},
    {154, 125},
    {144, 125},
    {216, 195},
    {320, 265},
    {384, 265},
    {600, 335}
  ]
  @area_markup_category "h3GrtaTf5ipFicdrJ"

  import Ecto.Query, only: [from: 2]

  alias Picsello.{Repo, WHCC.Adapter, WHCC.Editor.Params, WHCC.Editor.Details}

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

  defdelegate get_existing_editor(account_id, editor_id), to: Adapter
  defdelegate editor_details(account_id, editor_id), to: Adapter
  defdelegate editor_export(account_id, editor_id), to: Adapter
  defdelegate editor_clone(account_id, editor_id), to: Adapter
  defdelegate create_order(account_id, editor_id, opts), to: Adapter
  defdelegate confirm_order(account_id, confirmation), to: Adapter
  defdelegate webhook_register(url), to: Adapter
  defdelegate webhook_verify(hash), to: Adapter
  defdelegate webhook_validate(data, signature), to: Adapter

  def price_details(editor_id, account_id) do
    details = editor_details(account_id, editor_id)
    base_price = editor_export(account_id, editor_id) |> Picsello.WHCC.Editor.Export.price()
    details |> get_product |> price_details(details, base_price)
  end

  def price_details(%{category: category} = product, details, base_price) do
    %{
      markup: mark_up_price(product, details, base_price),
      editor_details: details,
      base_price: base_price
    }
    |> Map.merge(Map.take(category, [:shipping_upcharge, :shipping_base_charge]))
  end

  defp get_product(%Details{product_id: product_id}) do
    from(product in Picsello.Product,
      join: category in assoc(product, :category),
      where: product.whcc_id == ^product_id,
      preload: [category: category]
    )
    |> Repo.one!()
  end

  defp mark_up_price(
         product,
         %{selections: selections},
         %Money{} = price
       ) do
    case product do
      %{
        category: %{whcc_id: @area_markup_category} = category,
        attribute_categories: attribute_categories
      } ->
        size = Map.get(selections, "size")

        [metadata] =
          for(
            %{"name" => "size", "attributes" => attributes} <- attribute_categories,
            %{"id" => ^size, "metadata" => %{"height" => _, "width" => _} = metadata} <-
              attributes,
            do: metadata
          )

        category
        |> mark_up_price(%{metadata: metadata})
        |> Money.multiply(Map.get(selections, "quantity", 1))

      %{category: category} ->
        mark_up_price(category, %{price: price})
    end
    |> Money.subtract(price)
  end

  defp mark_up_price(
         %{whcc_id: @area_markup_category} = _category,
         %{
           metadata: %{"height" => height, "width" => width}
         } = _selection_summary
       ) do
    [{_, dollars} | _] = Enum.sort_by(@area_markups, &abs(height * width - elem(&1, 0)))
    Money.new(dollars * 100)
  end

  defp mark_up_price(%{default_markup: default_markup}, %{price: price}) do
    price
    |> Money.multiply(default_markup)
  end

  def min_price_details(%{products: [_ | _] = products} = category) do
    products
    |> Enum.map(&{&1, cheapest_selections(&1)})
    |> Enum.min_by(fn {_, %{price: price}} -> price end)
    |> then(fn {product, %{price: price} = details} ->
      price_details(
        %{product | category: category},
        details,
        price
      )
    end)
  end

  defdelegate cheapest_selections(product), to: Picsello.WHCC.Product

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
      Picsello.Category.active()
      |> Picsello.Category.shown()
      |> Picsello.Category.order_by_position()

  defp async_stream(enum, f) do
    enum
    |> Task.async_stream(f)
    |> Enum.to_list()
    |> Keyword.get_values(:ok)
  end
end
