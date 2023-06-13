defmodule Picsello.Repo.Migrations.CreateTableEmailSchedules do
  use Ecto.Migration

  @table "email_schedules"
  def up do
    create table(@table) do
      add(:state, :string, null: false)
      add(:type, :email_automation_type, null: false)
      add(:total_hours, :integer)
      add(:condition, :string)
      add(:private_name, :string)
      add(:body_template, :text, null: false)
      add(:subject_template, :text, null: false)
      add(:name, :text, null: false)
      add(:reminded_at, :utc_datetime)
      add(:is_stop, :boolean, null: false, default: false)
      add(:job_id, references(:jobs, on_delete: :nothing))
      add(:gallery_id, references(:galleries, on_delete: :nothing))

      add(
        :email_automation_pipeline_id,
        references(:email_automation_pipelines, on_delete: :nothing)
      )

      add(
        :email_automation_sub_category_id,
        references(:email_automation_sub_categories, on_delete: :nothing)
      )

      add(
        :email_automation_category_id,
        references(:email_automation_categories, on_delete: :nothing)
      )

      add(:organization_id, references(:organizations, on_delete: :nothing))
      timestamps()
    end
    create(index(@table, [:job_id, :gallery_id]))
  end

  def down do
    drop(table(@table))
  end

end
