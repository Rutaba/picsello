defmodule Picsello.Repo.Migrations.PackageThumbnail do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add(:thumbnail_url, :string)
    end
  end
end
