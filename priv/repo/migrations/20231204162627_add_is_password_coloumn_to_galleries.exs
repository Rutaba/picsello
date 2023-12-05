defmodule Picsello.Repo.Migrations.AddIsPasswordColoumnToGalleries do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      add(:is_password, :boolean, null: false, default: true)
    end

  end
end
