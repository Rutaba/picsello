defmodule Picsello.Repo.Migrations.AddTotalCountToGallery do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      add(:total_count, :integer)
    end
  end
end
