defmodule Picsello.Repo.Migrations.ChangeUseGlobalFieldTypeInGallery do
  use Ecto.Migration

  alias Ecto.Multi
  alias Picsello.Repo

  @default %{expiration: true, watermark: true, products: true, digital: true}

  def change do
    galleries = Gallery.list()

    alter table(:galleries) do
      remove(:use_global)
      add(:use_global, :map, null: false, default: @default)
    end

    flush()

    galleries
    |> Enum.reduce(Multi.new(), fn %{id: id} = gallery, multi ->
      Multi.update(multi, id, Gallery.change(gallery))
    end)
    |> Repo.transaction()
  end
end

defmodule Gallery do
  use Ecto.Schema

  import Ecto.Changeset, only: [change: 2]
  alias Picsello.Repo

  import Ecto.Query, from: 2

  schema "galleries" do
    field :use_global, :map
  end

  def change(%{use_global: value, id: id}) do
    params = %{expiration: value, watermark: value, products: value, digital: value}

    change(%Gallery{id: id}, %{use_global: params})
  end

  def list() do
    from(g in "galleries",
      select: %{id: g.id, use_global: g.use_global}
    )
    |> Repo.all()
  end
end
