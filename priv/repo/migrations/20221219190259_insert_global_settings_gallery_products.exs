defmodule Picsello.Repo.Migrations.InsertGlobalSettingsGalleryProducts do
  use Ecto.Migration

  import Ecto.Query
  alias Ecto.Multi
  alias Picsello.GlobalSettings
  alias Picsello.GlobalSettings.GalleryProduct

  def change do
    gallery_products_params = GlobalSettings.gallery_products_params()

    from(org in Picsello.Organization,
      left_join: gallery_product in assoc(org, :gs_gallery_products),
      where: is_nil(gallery_product.id),
      select: org.id
    )
    |> Picsello.Repo.all()
    |> Enum.reduce(Multi.new(), fn org_id, multi ->
      gallery_products_params
      |> Enum.reduce(multi, fn %{category_id: category_id} = params, ecto_multi ->
        ecto_multi
        |> Multi.insert(
          "insert_gs_gallery_product#{org_id}#{category_id}",
          params
          |> Map.put(:organization_id, org_id)
          |> GalleryProduct.changeset()
        )
      end)
    end)
    |> Picsello.Repo.transaction()
  end
end
