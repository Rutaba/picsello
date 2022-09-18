defmodule Picsello.Repo.Migrations.AddPhotographerLikedToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add(:is_photographer_liked, :boolean, default: false)
    end
  end
end
