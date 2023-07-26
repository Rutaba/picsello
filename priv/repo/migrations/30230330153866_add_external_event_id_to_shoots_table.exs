defmodule Picsello.Repo.Migrations.AddExternalEventIdToShootsTable do
  use Ecto.Migration

  def change do
    alter table(:shoots) do
      modify(:external_event_id, :string)
    end
  end
end
