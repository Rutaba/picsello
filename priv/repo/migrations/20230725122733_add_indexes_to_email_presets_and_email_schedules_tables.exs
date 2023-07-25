defmodule Picsello.Repo.Migrations.AddIndexesToEmailPresetsAndEmailSchedulesTables do
  use Ecto.Migration

  def up do
    create index(:email_presets, [:email_automation_pipeline_id, :organization_id, :job_type, :gallery_id])
  end

  def down do
    drop index(:email_presets, [:email_automation_pipeline_id, :organization_id, :job_type, :gallery_id])
  end
end
