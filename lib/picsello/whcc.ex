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
  @area_markup_category "h3GrtaTf5ipFicdrJ"

  require Logger
  import Ecto.Query, only: [from: 2]

  alias Picsello.{Repo, WHCC.Adapter, WHCC.Editor}

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

  def create_order(account_id, %{items: items} = export) do
    case Adapter.create_order(account_id, export) do
      {:ok, %{orders: orders} = created_order} ->
        for(
          order <- orders,
          item <- items,
          item.order_sequence_number == order.sequence_number
        ) do
          %{order | editor_id: item.id}
        end
        |> case do
          matched_orders when length(orders) == length(matched_orders) ->
            {:ok, %{created_order | orders: matched_orders}}

          _ ->
            {:error,
             "order missing some items. sub-orders:#{inspect(orders)}\nitems:#{inspect(items)}"}
        end

      err ->
        err
    end
  end

  def price_details(account_id, editor_id) do
    details = editor_details(account_id, editor_id)
    %{items: [item]} = editors_export(account_id, [Editor.Export.Editor.new(editor_id)])

    details
    |> get_product
    |> price_details(
      details,
      item |> Map.from_struct() |> Map.take([:unit_base_price, :quantity])
    )
  end

  def price_details(%{category: category, id: whcc_product_id} = product, details, %{
        unit_base_price: unit_price,
        quantity: quantity
      }) do
    %{
      unit_markup: mark_up_price(product, details, unit_price),
      unit_price: unit_price,
      quantity: quantity
    }
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

  defp get_product(%Editor.Details{product_id: product_id}) do
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
