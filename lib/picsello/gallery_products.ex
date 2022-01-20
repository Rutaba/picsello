defmodule Picsello.GalleryProducts do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Picsello.Repo
  alias Picsello.Product
  alias Picsello.Galleries.GalleryProduct

  def get(fields) do
    Repo.get_by(GalleryProduct, fields)
    |> Repo.preload([:preview_photo, :category_template])
  end

  @doc """
  Get all the gallery products that are ready for review
  """
  def get_gallery_products(gallery_id) do
    from(product in GalleryProduct,
      where: product.gallery_id == ^gallery_id and not is_nil(product.preview_photo_id),
      inner_join: preview_photo in Picsello.Galleries.Photo,
      on: product.preview_photo_id == preview_photo.id,
      inner_join: category_template in Picsello.CategoryTemplate,
      on: product.category_template_id == category_template.id,
      select_merge: %{preview_photo: preview_photo, category_template: category_template}
    )
    |> Repo.all()
  end

  @doc """
  Product sourcing and creation.
  """
  def get_or_create_gallery_product(gallery_id, category_template_id) do
    get_gallery_product(gallery_id, category_template_id)
    |> case do
      nil ->
        Repo.insert!(%GalleryProduct{
          gallery_id: gallery_id,
          category_template_id: category_template_id
        })

      product ->
        product
    end
    |> Repo.preload([:preview_photo, :category_template])
  end

  @doc """
  Product search.
  """
  def get_gallery_product(gallery_id, category_template_id) do
    GalleryProduct
    |> Repo.get_by(gallery_id: gallery_id, category_template_id: category_template_id)
  end

  @doc """
  Gets WHCC products with size params.
  """
  def get_whcc_products(category_id) do
    from(product in Product,
      where: product.category_id == ^category_id,
      order_by: [asc: product.position],
      select:
        merge(product, %{
          sizes:
            fragment(
              ~s|SELECT object->'attributes' FROM jsonb_array_elements(attribute_categories) AS object WHERE object->>'_id' = 'size'|
            )
        })
    )
    |> Repo.all()
  end

  @doc """
  Gets WHCC product by WHCC product id.
  """
  def get_whcc_product(whcc_id) do
    Repo.get_by(Product, whcc_id: whcc_id)
  end

  def get_whcc_product_category(whcc_id) do
    whcc_id
    |> get_whcc_product()
    |> Repo.preload(:category)
    |> then(& &1.category)
  end
end
