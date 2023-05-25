defmodule Picsello.Repo.Migrations.AddTypeInGallery do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE gallery_types AS ENUM ('standard','proofing','finals')")

    alter table(:galleries) do
      add(:type, :gallery_types, null: false, default: "standard")
      add(:parent_id, references(:galleries, on_delete: :nothing))
    end
  end
end
