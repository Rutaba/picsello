defmodule Picsello.Repo.Migrations.AddArchivedAtToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add(:archived_at, :utc_datetime)
    end
  end
end
