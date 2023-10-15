defmodule Picsello.Repo.Migrations.AddDatesToGalleries do
  use Ecto.Migration

  def up do
    alter table(:galleries) do
      add(:password_regenerated_at, :utc_datetime)
      add(:gallery_send_at, :utc_datetime)
    end
  end

  def down do
    alter table(:galleries) do
      remove(:password_regenerated_at)
      remove(:gallery_send_at)
    end
  end
end
