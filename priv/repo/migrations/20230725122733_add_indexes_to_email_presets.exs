defmodule Picsello.Repo.Migrations.AddIndexesToEmailPresets do
  use Ecto.Migration

  def up do
    create index(:email_presets, [:email_automation_pipeline_id, :organization_id, :job_type])
  end

  def down do
    drop index(:email_presets, [:email_automation_pipeline_id, :organization_id, :job_type])
  end
end
