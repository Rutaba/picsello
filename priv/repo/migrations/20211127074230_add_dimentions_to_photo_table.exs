defmodule Picsello.Repo.Migrations.AddDimentionsToPhotoTable do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add(:height, :integer)
      add(:width, :integer)
    end
  end
end
