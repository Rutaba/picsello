defmodule Picsello.Repo.Migrations.UpdatePackageDigitalDownloads do
  use Ecto.Migration

  def change do
    alter table("packages") do
      remove(:gallery_credit, :integer)
    end
  end
end
