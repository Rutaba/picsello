defmodule Picsello.Repo.Migrations.AddIndexesToEmailPresetsAndEmailSchedulesTables do
  use Ecto.Migration

  def up do
    create index(:email_presets, [:email_automation_pipeline_id])
    create index(:email_presets, [:organization_id])
    create index(:email_schedules, [:job_id])
    create index(:email_schedules, [:gallery_id])
    create index(:email_schedules, [:email_automation_pipeline_id])
  end

  def down do
    drop index(:email_presets, [:email_automation_pipeline_id])
    drop index(:email_presets, [:organization_id])
    drop index(:email_schedules, [:job_id])
    drop index(:email_schedules, [:gallery_id])
    drop index(:email_schedules, [:email_automation_pipeline_id])
  end
end
