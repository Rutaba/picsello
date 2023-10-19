defmodule Picsello.Repo.Migrations.AddIsRepeatingToBookingEvents do
  use Ecto.Migration

  @table "email_schedules"
  def up do
    alter table(@table) do
      add(:type, :string, null: false)
    end

    drop(constraint(@table, :job_gallery_constraint))
  end

  def down do
    check =
      "(job_id IS NOT NULL AND gallery_id IS NULL) or (gallery_id IS NOT NULL AND job_id IS NULL)"

    create(constraint(@table, :job_gallery_constraint, check: check))
  end
end
