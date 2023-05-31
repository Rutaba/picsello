defmodule Picsello.Repo.Migrations.ExternalCalendars do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:external_calendar_rw_id, :string, null: true)
      add(:external_calendar_read_list, {:array, :string}, null: true)
    end
  end

  def down do
    alter table(:users) do
      remove_if_exists(:external_calendar_rw_id, :string)
      remove_if_exists(:external_calendar_read_list, {:array, :string})
    end
  end
end
