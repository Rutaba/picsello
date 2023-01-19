defmodule Mix.Tasks.InsertGlobalSettings do
  @moduledoc false

  use Mix.Task
  import Ecto.Query
  alias Ecto.Multi
  alias Picsello.{Organization, GlobalSettings.GalleryProduct, GlobalSettings, Repo}

  @shortdoc "Insert global settings"
  def run(_) do
    load_app()

    gallery_products_params = GlobalSettings.gallery_products_params()

    from(org in Organization,
      left_join: gallery_product in assoc(org, :gs_gallery_products),
      where: is_nil(gallery_product.id),
      select: org.id
    )
    |> Repo.all()
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
    |> Repo.transaction()
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
