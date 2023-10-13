defmodule Picsello.Repo.Migrations.AddIsReservedToJobs do
  use Ecto.Migration

  def up do
    alter table(:jobs) do
      add(:is_reserved?, :boolean, default: false)
    end
  end

  def down do
    alter table(:jobs) do
      remove(:is_reserved?)
    end
  end
end
