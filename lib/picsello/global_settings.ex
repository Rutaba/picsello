defmodule Picsello.GlobalSettings do
  alias Picsello.GlobalSettings.GalleryProduct, as: GSGalleryProduct
  alias Picsello.GlobalSettings.PrintProduct, as: GSPrintProduct
  alias Picsello.Repo
  alias Ecto.Multi
  alias Picsello.Galleries.GalleryProduct
  alias Picsello.Category
  import Ecto.Query

  @whcc_print_categroy "h3GrtaTf5ipFicdrJ"

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
          where: gallery.use_global == true,
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
    GSGalleryProduct
    |> where([gallery_product], gallery_product.organization_id == ^organization_id)
    |> preload(category: [:products])
    |> Repo.all()
  end

  def insert_gallery_products(organization_id) when is_integer(organization_id) do
    categories = from(c in Category, preload: :products) |> Repo.all()

    print_category =
      categories
      |> Enum.find(&(&1.whcc_id == @whcc_print_categroy))
      |> Map.get(:products)
      |> Enum.map(fn product ->
        product = Picsello.Repo.preload(product, :category)
        {categories, selections} = Picsello.Product.selections_with_prices(product)
        build_selections(selections, categories, product.id)
      end)

    Multi.new()
    |> Multi.run(:insert_gs_gallery_product, fn repo, _ ->
      Enum.each(categories, fn category ->
        %GSGalleryProduct{}
        |> GSGalleryProduct.changeset(%{
          category_id: category.id,
          organization_id: organization_id,
          global_settings_print_products: print_products(category.whcc_id, print_category)
        })
        |> repo.insert!()
      end)

      {:ok, :inserted}
    end)
    |> Repo.transaction()
  end

  def size([base_cost, _, _, _, _, size, type], ["size", _]), do: size(base_cost, size, type)
  def size([base_cost, _, _, _, _, type, size], [_, "size"]), do: size(base_cost, size, type)
  def size(base_cost, size, type), do: %{base_cost: base_cost, size: size, type: type}

  defp build_selections(selections, categories, product_id) do
    selections
    |> Enum.map(&size(&1, categories))
    |> then(&%{product_id: product_id, sizes: &1})
  end

  defp print_products(@whcc_print_categroy, print_category), do: print_category
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
end
