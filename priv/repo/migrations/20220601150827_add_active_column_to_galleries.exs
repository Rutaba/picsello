defmodule Picsello.Repo.Migrations.AddActiveColumnToGalleries do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      add(:active, :boolean, null: false, default: true)
    end

    alter table(:photos) do
      add(:active, :boolean, null: false, default: true)
    end

    execute("update galleries set active = true", "")
    execute("update photos set active = true", "")
  end
end
