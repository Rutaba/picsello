defmodule Picsello.Repo.Migrations.AddUseGlobalToGalleries do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      add(:use_global, :boolean, null: false, default: false)
    end
  end
end
