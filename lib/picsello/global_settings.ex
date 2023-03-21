defmodule Picsello.GlobalSettings do
  @moduledoc false
  alias Picsello.GlobalSettings.GalleryProduct, as: GSGalleryProduct
  alias Picsello.GlobalSettings.PrintProduct, as: GSPrintProduct
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Picsello.{Repo, Category}
  alias Ecto.Multi
  alias Picsello.Galleries.GalleryProduct
  import Ecto.Query

  @whcc_print_category Category.print_category()

  def update_gallery_product(%GSGalleryProduct{} = gs_gallery_product, opts)
      when is_list(opts) do
    attrs = Enum.into(opts, %{})

    Multi.new()
    |> Multi.update(:gs_gallery_product, GSGalleryProduct.changeset(gs_gallery_product, attrs))
    |> Multi.update_all(
      :gallery_products,
      fn %{gs_gallery_product: gs_gallery_product} ->
        from(gallery_product in GalleryProduct,
          join: gallery in assoc(gallery_product, :gallery),
          join: job in assoc(gallery, :job),
          join: client in assoc(job, :client),
          where: fragment("? ->> 'products' = 'true'", gallery.use_global),
          where: client.organization_id == ^gs_gallery_product.organization_id,
          where: gallery_product.category_id == ^gs_gallery_product.category_id,
          update: [set: ^opts]
        )
      end,
      []
    )
    |> Repo.transaction()
  end

  def update_gallery_product(%GSGalleryProduct{} = gs_gallery_product, %{} = attrs) do
    gs_gallery_product
    |> GSGalleryProduct.changeset(attrs)
    |> Repo.update()
  end

  def list_gallery_products(organization_id) do
    gallery_product_query()
    |> where([gs_gp], gs_gp.organization_id == ^organization_id)
    |> order_by([_, category], category.position)
    |> Repo.all()
  end

  def gallery_product(id) do
    gallery_product_query()
    |> where([gs_gp], gs_gp.id == ^id)
    |> Repo.one()
  end

  defp gallery_product_query() do
    GSGalleryProduct
    |> join(:inner, [gs_gp], category in assoc(gs_gp, :category))
    |> preload([gs_gp, category], category: {category, [:products, gs_gallery_products: gs_gp]})
  end

  def gallery_products_params() do
    categories = from(c in Category, preload: :products, where: not c.hidden) |> Repo.all()

    categories
    |> Enum.find(%{}, &(&1.whcc_id == @whcc_print_category))
    |> Map.get(:products, [])
    |> Enum.map(fn product ->
      product = Picsello.Repo.preload(product, :category)
      {categories, selections} = Picsello.Product.selections_with_prices(product)
      build_selections(selections, categories, product.id)
    end)
    |> then(fn print_category ->
      Enum.map(
        categories,
        &%{
          category_id: &1.id,
          markup: &1.default_markup,
          global_settings_print_products: print_products(&1.whcc_id, print_category)
        }
      )
    end)
  end

  def size([total_cost, shipping_cost, print_cost, _, rounding, size, type], ["size", _]),
    do: size(total_cost, add([shipping_cost, print_cost, rounding]), size, type)

  def size([total_cost, shipping_cost, print_cost, _, rounding, type, size], [_, "size"]),
    do: size(total_cost, add([shipping_cost, print_cost, rounding]), size, type)

  def size(
        [
          total_cost,
          shipping_cost,
          print_cost,
          _,
          rounding,
          type,
          _mounting,
          size,
          _surface,
          _texture
        ],
        [_, _, "size", _, _]
      ),
      do: size(total_cost, add([shipping_cost, print_cost, rounding]), size, type)

  def size([total_cost, shipping_cost, print_cost, _, rounding, _mounting, type, size], [
        _,
        _,
        "size"
      ]),
      do: size(total_cost, add([shipping_cost, print_cost, rounding]), size, type)

  def size(final_cost, base_cost, size, type),
    do: %{final_cost: to_decimal(final_cost), base_cost: base_cost, size: size, type: type}

  defp add(values) do
    Enum.reduce(values, Money.new(0), fn value, total -> Money.add(total, value) end)
  end

  def to_decimal(%Money{amount: amount, currency: :USD}),
    do: Decimal.round(to_string(amount / 100), 2)

  defp build_selections(selections, categories, product_id) do
    selections
    |> Enum.map(&size(&1, categories))
    |> then(&%{product_id: product_id, sizes: &1})
  end

  defp print_products(@whcc_print_category, print_category), do: print_category
  defp print_products(_whcc_print_categroy, _print_category), do: []

  def list_print_products(gs_gallery_product_id) do
    from(gs_print_product in GSPrintProduct,
      where: gs_print_product.global_settings_gallery_product_id == ^gs_gallery_product_id
    )
    |> Repo.all()
  end

  def update_print_product!(%GSPrintProduct{} = gs_print_product, %{} = attrs) do
    gs_print_product
    |> GSPrintProduct.changeset(attrs)
    |> Repo.update!()
  end

  def get(organization_id), do: Repo.get_by(GSGallery, organization_id: organization_id)
end
