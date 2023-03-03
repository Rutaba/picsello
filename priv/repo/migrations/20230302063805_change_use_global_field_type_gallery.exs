defmodule Picsello.Repo.Migrations.ChangeUseGlobalFieldTypeInGallery do
  use Ecto.Migration

  alias Picsello.Repo
  alias Ecto.Multi

  import Ecto.Query

  def change do
    galleries = Repo.all(from(g in "galleries", select: %{id: g.id, use_global: g.use_global}))

    alter table(:galleries) do
      remove(:use_global)
      add(:use_global, :map, null: false, default: %{expiration: true, watermark: true})
    end

    flush()

    Enum.reduce(galleries, Multi.new(), fn %{id: id} = gallery, multi ->
      multi
      |> Multi.update(id, Gallery.change(gallery))
    end)
    |> Repo.transaction()
  end
end

defmodule Gallery do
  use Ecto.Schema
  alias Ecto.Changeset

  schema "galleries" do
    field :use_global, :map
  end

  def change(%{use_global: use_global, id: id}) do
    Changeset.change(%Gallery{id: id}, %{
      use_global: %{expiration: use_global, watermark: use_global, products: use_global}
    })
  end
end
