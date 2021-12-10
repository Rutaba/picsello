defmodule Picsello.Repo.Migrations.AddDeletedAtToClientMessages do
  use Ecto.Migration

  def change do
    alter table(:client_messages) do
      add(:deleted_at, :utc_datetime)
    end
  end
end
