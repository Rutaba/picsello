defmodule Picsello.Repo.Migrations.AddTimeZoneToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:time_zone, :string, null: true, default: "America/New_York")
    end
  end
end
