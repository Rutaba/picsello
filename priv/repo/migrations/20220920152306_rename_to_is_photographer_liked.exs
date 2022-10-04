defmodule Picsello.Repo.Migrations.RenametoIsPhotographerLiked do
  use Ecto.Migration

  def change do
      rename(table(:photos), :photographer_liked, to: :is_photographer_liked)
  end
end
