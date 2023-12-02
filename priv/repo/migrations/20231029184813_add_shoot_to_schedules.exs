defmodule Picsello.Repo.Migrations.AddShootToSchedules do
  use Ecto.Migration
  @table "email_schedules"

  def up do
    alter table(@table) do
      add(:shoot_id, references(:shoots, on_delete: :nothing))
    end
  end

  def down do
    alter table(@table) do
      remove(:shoot_id)
    end
  end
end
