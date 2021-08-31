defmodule Picsello.Repo.Migrations.AddArchivedAtToJob do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add(:archived_at, :utc_datetime)
    end
  end
end
