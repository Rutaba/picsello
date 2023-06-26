defmodule Picsello.Repo.Migrations.CreateTableEmailSchedules do
  use Ecto.Migration

  @table "email_schedules"
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

      add(
        :email_automation_pipeline_id,
        references(:email_automation_pipelines, on_delete: :nothing)
      )

      timestamps()
    end

    check =
      "(job_id IS NOT NULL AND gallery_id IS NULL ) or (gallery_id IS NOT NULL AND job_id IS NULL)"

    create(constraint(:email_schedules, :job_gallery_constraint, check: check))
    create(index(@table, [:job_id, :gallery_id]))
  end

  def down do
    drop(constraint(:email_schedules, :job_gallery_constraint))
    drop(table(@table))
  end
end
