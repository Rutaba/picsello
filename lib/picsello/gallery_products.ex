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

  @spec get_gallery_products(gallery_id :: integer) :: [GalleryProduct.t()]
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

  @spec get_or_create_gallery_product(gallery_id :: integer, category_template_id :: integer) ::
          GalleryProduct.t()
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

  @spec get_gallery_product(gallery_id :: integer, category_template_id :: integer) ::
          GalleryProduct.t() | nil
  def get_gallery_product(gallery_id, category_template_id) do
    GalleryProduct
    |> Repo.get_by(gallery_id: gallery_id, category_template_id: category_template_id)
  end

  def get_whcc_products(category_id) do
    from(product in Product,
      where: product.category_id == ^category_id,
      order_by: [asc: product.position],
      select: %{
        id: product.id,
        whcc_name: product.whcc_name,
        sizes:
          fragment(
            ~s|SELECT object->'attributes' FROM jsonb_array_elements(attribute_categories) AS object WHERE object->>'_id' = 'size'|
          )
      }
    )
    |> Repo.all()
  end

  # def get_whcc_print_products() do
  #  :print
  #  |> whcc_products_query()
  #  |> Repo.all()
  # end
  #
  # def get_whcc_framed_print_product() do
  #  :framed_print
  #  |> whcc_products_query()
  #  |> Repo.one()
  # end
  #
  # def get_whcc_album_product() do
  #  :album
  #  |> whcc_products_query()
  #  |> Repo.one()
  # end

  # defp whcc_products_query(:print) do
  #  from(category in Category,
  #    where: category.name in ["Wall Displays", "Loose Prints"],
  #    join: product in Product,
  #    on: product.category_id == category.id,
  #    order_by: [asc: product.position],
  #    select: struct(product, @products_select_attributes)
  #  )
  # end
  #
  # defp whcc_products_query(:framed_print) do
  #  from(product in Product,
  #    where: product.whcc_name == "Framed Print",
  #    select: struct(product, @products_select_attributes)
  #  )
  # end
  #
  # defp whcc_products_query(:album) do
  #  from(product in Product,
  #    where: product.whcc_name == "Album",
  #    select: struct(product, @products_select_attributes)
  #  )
  # end
end
