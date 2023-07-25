defmodule Picsello.Repo.Migrations.AddEmailSchedulesHistoryTable do
  use Ecto.Migration

  @table "email_schedules_history"

  def up do
    create table(@table) do
      add(:total_hours, :integer)
      add(:condition, :string)
      add(:private_name, :string)
      add(:body_template, :text, null: false)
      add(:subject_template, :text, null: false)
      add(:name, :text, null: false)
      add(:reminded_at, :utc_datetime)
      add(:is_stopped, :boolean, null: false, default: false)
      add(:job_id, references(:jobs, on_delete: :nothing))
      add(:gallery_id, references(:galleries, on_delete: :nothing))
      add(:order_id, references(:gallery_orders, on_delete: :nothing))
      add(:organization_id, references(:organizations, on_delete: :nothing))

      add(
        :email_automation_pipeline_id,
        references(:email_automation_pipelines, on_delete: :nothing)
      )

      timestamps()
    end

    check =
      "(job_id IS NOT NULL AND gallery_id IS NULL ) or (gallery_id IS NOT NULL AND job_id IS NULL)"

    create(constraint(@table, :job_gallery_constraint, check: check))
    create(index(@table, [:job_id, :gallery_id, :order_id, :email_automation_pipeline_id, :organization_id]))
  end

  def down do
    drop(constraint(@table, :job_gallery_constraint))
    drop index(@table, [:job_id, :gallery_id, :order_id, :email_automation_pipeline_id, :organization_id])
    drop(table(@table))
  end
end
