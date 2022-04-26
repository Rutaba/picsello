defmodule Picsello.GalleryProducts do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Picsello.Repo
  alias Picsello.Product
  alias Picsello.Galleries.GalleryProduct

  def get(fields) do
    GalleryProduct
    |> Repo.get_by(fields)
    |> Repo.preload([:preview_photo, category: :products])
  end

  @doc """
  Get all the gallery products that are ready for review
  """
  def get_gallery_products(gallery_id, opts \\ :with_previews) do
    gallery_id |> gallery_products_query(opts) |> Repo.all()
  end

  defp gallery_products_query(gallery_id, :with_previews) do
    from(product in gallery_products_query(gallery_id, :with_or_without_previews),
      inner_join: preview_photo in subquery(Picsello.Photos.watermarked_query()),
      on: preview_photo.id == product.preview_photo_id,
      select_merge: %{preview_photo: preview_photo}
    )
  end

  defp gallery_products_query(gallery_id, :with_or_without_previews) do
    from(product in GalleryProduct,
      inner_join: category in assoc(product, :category),
      where:
        product.gallery_id == ^gallery_id and not category.hidden and is_nil(category.deleted_at),
      preload: [:preview_photo, category: :products],
      order_by: category.position
    )
  end

  def check_is_photo_selected_as_preview(photo_id) do
    from(p in Picsello.Galleries.GalleryProduct,
      where: p.preview_photo_id == ^photo_id
    )
    |> Repo.update_all(set: [preview_photo_id: nil])
  end

  @doc """
  Product sourcing and creation.
  """
  def get_or_create_gallery_product(gallery_id, category_id) do
    get_gallery_product(gallery_id, category_id)
    |> case do
      nil ->
        %GalleryProduct{
          gallery_id: gallery_id,
          category_id: category_id
        }
        |> Repo.insert!()

      product ->
        product
    end
    |> Repo.preload([:preview_photo, category: :products])
  end

  @doc """
  Product search.
  """
  def get_gallery_product(gallery_id, category_id) do
    GalleryProduct
    |> Repo.get_by(gallery_id: gallery_id, category_id: category_id)
  end

  @doc """
  Gets WHCC products with size params.
  """

  @product_sizes """
  select
  products.id as product_id,
  jsonb_agg(
  jsonb_build_object('id', attributes.id, 'name', attributes.name)
  order by
    (metadata -> 'height') :: decimal * (metadata -> 'width') :: decimal
  ) as sizes
  from
  products,
  jsonb_to_recordset(products.attribute_categories) as attribute_categories(attributes jsonb, name text, _id text),
  jsonb_to_recordset(attribute_categories.attributes) as attributes(name text, id text, metadata jsonb)
  where
  attribute_categories._id = 'size'
  group by
  products.id
  """

  def get_whcc_products(category_id) do
    from(product in Product,
      where: product.category_id == ^category_id and is_nil(product.deleted_at),
      inner_join: sizes in fragment(@product_sizes),
      on: sizes.product_id == product.id,
      order_by: [asc: product.position],
      select: merge(product, %{sizes: sizes.sizes})
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
