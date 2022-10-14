defmodule Picsello.Repo.Migrations.CreatePackagePaymentPresets do
  use Ecto.Migration

  @table :package_payment_presets
  def change do
    create table(@table) do
      add(:schedule_type, :string, null: false)
      add(:job_type, :string, null: false)
      add(:fixed, :boolean, null: false)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(@table, [:organization_id]))
  end
end
