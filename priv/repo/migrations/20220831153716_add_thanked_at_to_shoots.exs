defmodule Picsello.Repo.Migrations.AddThankedAtToShoots do
  use Ecto.Migration

  def change do
    alter table(:shoots) do
      add(:thanked_at, :utc_datetime)
    end
  end
end
