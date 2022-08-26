defmodule Picsello.Repo.Migrations.CreatePackagePaymentSchedules do
  use Ecto.Migration

  @table :package_payment_schedules
  def change do
    create table(@table) do
      add(:interval, :boolean, null: false)
      add(:price, :integer)
      add(:percentage, :integer)
      add(:due_interval, :string)
      add(:count_interval, :string)
      add(:time_interval, :string)
      add(:shoot_interval, :string)
      add(:due_at, :date)
      add(:schedule_date, :date)
      add(:package_id, references(:packages, on_delete: :nothing))
      add(:package_payment_preset_id, references(:package_payment_presets, on_delete: :nothing))

      timestamps()
    end

    create(index(@table, [:package_id, :package_payment_preset_id]))
  end
end
