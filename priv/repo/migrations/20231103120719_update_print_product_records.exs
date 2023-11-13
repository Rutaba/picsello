defmodule Picsello.Repo.Migrations.UpdatePrintProductRecords do
  use Ecto.Migration

  import Ecto.Query
  alias Picsello.{Repo, GlobalSettings.PrintProduct}
  alias Ecto.{Multi, Changeset}

  def change do
    PrintProduct
    |> Repo.all()
    |> Enum.reduce(Multi.new(), fn %{sizes: sizes} = p_product, multi ->
      sizes =
        Enum.map(
          sizes,
          &((&1.type == "glossy" && %{id: &1.id, type: "fuji_pearl"}) || %{id: &1.id})
        )

      Multi.update(multi, p_product.id, changeset(p_product, %{sizes: sizes}))
    end)
    |> Repo.transaction()
  end

  defp changeset(gs_gallery_product, attrs) do
    gs_gallery_product
    |> Changeset.cast(attrs, [])
    |> Changeset.cast_embed(:sizes, with: &size_type_changeset/2)
  end

  def size_type_changeset(size_type, attrs) do
    size_type
    |> Changeset.cast(attrs, [:type])
  end
end
