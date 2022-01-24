defmodule Picsello.Repo.Migrations.AddPreviousSlugToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add(:previous_slug, :string)
    end
  end
end
