defmodule Picsello.WHCC do
  @moduledoc "WHCC context module"

  # extracted from https://docs.google.com/spreadsheets/d/19epUUDsDmHWNePViH9v8x5BXGp0Anu0x/edit#gid=1549535757
  # {in², $dollars}
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
  @area_markup_category Picsello.Category.print_category()

  require Logger
  import Ecto.Query, only: [from: 2]

  alias Picsello.{Repo, WHCC.Adapter, WHCC.Editor, Galleries}

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
    |> Editor.Params.build(photo, opts)
    |> Adapter.editor()
  end

  def create_order(account_id, %{items: items, order: order} = export) do
    sub_orders = order["Orders"] || []

    case Adapter.create_order(account_id, export) do
      {:ok, %{orders: orders} = created_order} ->
        for %{sequence_number: sequence_number} = order <- orders do
          %{
            order
            | editor_ids:
                items
                |> Enum.filter(&(&1.order_sequence_number == sequence_number))
                |> Enum.map(& &1.id)
          }
        end
        |> case do
          order when length(orders) == length(sub_orders) ->
            {:ok, %{created_order | orders: order}}

          _ ->
            {:error,
             "order missing some items. sub-orders:#{inspect(orders)}\nitems:#{inspect(items)}"}
        end

      err ->
        err
    end
  end

  def price_details(gallery_id, editor_id) do
    %{photographer: %{organization_id: organization_id}, use_global: use_global} =
      Galleries.get_gallery!(gallery_id) |> Repo.preload(:photographer)

    account_id = Galleries.account_id(gallery_id)
    details = editor_details(account_id, editor_id)
    %{items: [item]} = editors_export(account_id, [Editor.Export.Editor.new(editor_id)])
    item_attrs = item |> Map.from_struct() |> Map.take([:unit_base_price, :quantity])

    details
    |> get_product!(organization_id)
    |> update_markup(%{use_global: use_global})
    |> price_details(details, item_attrs, %{use_global: use_global})
  end

  def price_details(product, details, other, opts \\ %{})

  def price_details(
        %{
          id: whcc_product_id,
          category: %{
            whcc_id: whcc_id,
            gs_gallery_products: [
              %{global_settings_print_products: print_products}
            ]
          }
        } = product,
        %{selections: %{"size" => size} = selections} = details,
        %{quantity: quantity},
        %{use_global: %{products: true}}
      )
      when whcc_id == @area_markup_category do
    type = selections["paper"] || selections["surface"]

    %{sizes: sizes} = Enum.find(print_products, &(&1.product_id == whcc_product_id))
    final_cost = Enum.find(sizes, &(&1.type == type && &1.size == size)) |> final_cost()

    %{
      unit_price: final_cost,
      unit_markup: Money.new(0)
    }
    |> merge_details(details, quantity, product)
  end

  def price_details(
        product,
        details,
        %{
          unit_base_price: unit_price,
          quantity: quantity
        },
        _
      ) do
    %{
      unit_markup: mark_up_price(product, details, unit_price),
      unit_price: unit_price
    }
    |> merge_details(details, quantity, product)
  end

  def merge_details(product_details, details, quantity, product) do
    %{category: category, id: whcc_product_id} = product

    product_details
    |> Map.put(:quantity, quantity)
    |> Map.merge(
      details
      |> Map.take([:preview_url, :editor_id, :selections])
    )
    |> Map.merge(
      category
      |> Map.from_struct()
      |> Map.take([:shipping_upcharge, :shipping_base_charge])
    )
    |> Map.merge(%{whcc_product: product, whcc_product_id: whcc_product_id})
  end

  def log(message),
    do:
      with(
        "" <> level <- Keyword.get(Application.get_env(:picsello, :whcc), :debug),
        do:
          level
          |> String.to_existing_atom()
          |> Logger.log("[WHCC] #{message}")
      )

  defdelegate get_existing_editor(account_id, editor_id), to: Adapter
  defdelegate editor_details(account_id, editor_id), to: Adapter
  defdelegate editors_export(account_id, editor_ids, opts \\ []), to: Adapter
  defdelegate editor_clone(account_id, editor_id), to: Adapter
  defdelegate confirm_order(account_id, confirmation), to: Adapter
  defdelegate webhook_register(url), to: Adapter
  defdelegate webhook_verify(hash), to: Adapter
  defdelegate webhook_validate(data, signature), to: Adapter

  defdelegate cheapest_selections(product), to: __MODULE__.Product
  defdelegate highest_selections(product), to: __MODULE__.Product
  defdelegate sync, to: __MODULE__.Sync

  def get_product!(%Editor.Details{product_id: product_id}, organization_id) do
    from(product in Picsello.Product,
      join: category in assoc(product, :category),
      left_join: gs_gallery_product in assoc(category, :gs_gallery_products),
      on: gs_gallery_product.organization_id == ^organization_id,
      where: product.whcc_id == ^product_id,
      preload: [
        category:
          {category, gs_gallery_products: {gs_gallery_product, :global_settings_print_products}}
      ]
    )
    |> Repo.one!()
  end

  def final_cost(%{final_cost: final_cost}),
    do: Money.multiply(Money.new(1), Decimal.mult(final_cost, 100))

  def update_markup(%{category: %{whcc_id: whcc_id}} = product, %{use_global: %{products: true}}) do
    %{category: %{gs_gallery_products: [%{markup: markup}]} = category} = product
    markup = if @area_markup_category == whcc_id, do: Decimal.new(0), else: markup

    %{product | category: %{category | default_markup: markup}}
  end

  def update_markup(product, _), do: product

  defp mark_up_price(
         product,
         %{selections: selections},
         %Money{} = unit_price
       ) do
    case product do
      %{
        category: %{whcc_id: @area_markup_category} = category
      } ->
        %{"size" => %{"metadata" => metadata}} =
          Picsello.WHCC.Product.selection_details(product, selections)

        mark_up_price(category, %{metadata: metadata, unit_price: unit_price})

      %{category: category} ->
        mark_up_price(category, unit_price)
    end
  end

  defp mark_up_price(
         %{whcc_id: @area_markup_category} = _category,
         %{
           metadata: %{"height" => height, "width" => width},
           unit_price: unit_price
         } = _selection_summary
       ) do
    [{_, dollars} | _] = Enum.sort_by(@area_markups, &abs(height * width - elem(&1, 0)))
    Money.new(dollars * 100) |> Money.subtract(unit_price)
  end

  defp mark_up_price(%{default_markup: default_markup}, %Money{} = unit_price),
    do: Money.multiply(unit_price, default_markup)

  def min_price_details(%{products: [_ | _] = products} = category) do
    products
    |> Enum.map(&{&1, cheapest_selections(&1)})
    |> Enum.min_by(fn {_, %{price: price}} -> price end)
    |> evaluate_price_details(category)
  end

  def max_price_details(%{products: [_ | _] = products} = category) do
    products
    |> Enum.map(&{&1, highest_selections(&1)})
    |> Enum.max_by(fn {_, %{price: price}} -> price end)
    |> evaluate_price_details(category)
  end

  defp evaluate_price_details({product, %{price: price} = details}, category) do
    price_details(
      %{product | category: category},
      details,
      %{unit_base_price: price, quantity: 1}
    )
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
      Picsello.Category.active()
      |> Picsello.Category.shown()
      |> Picsello.Category.order_by_position()
end
