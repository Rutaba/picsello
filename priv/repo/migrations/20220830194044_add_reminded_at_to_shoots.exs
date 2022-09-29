defmodule Picsello.Repo.Migrations.AddRemindedAtToShoots do
  use Ecto.Migration

  def change do
    alter table(:shoots) do
      add(:reminded_at, :utc_datetime)
    end
  end
end
