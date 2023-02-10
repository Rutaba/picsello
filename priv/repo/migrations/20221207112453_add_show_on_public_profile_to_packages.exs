defmodule Picsello.Repo.Migrations.AddShowOnPublicProfileToPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add(:show_on_public_profile, :boolean, default: false)
    end
  end
end
