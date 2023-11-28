defmodule Picsello.Repo.Migrations.AddGlobalAutomationEnabledFieldForOrganization do
  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add(:global_automation_enabled, :boolean, default: true)
    end
  end

  def down do
    alter table(:organizations) do
      remove(:global_automation_enabled)
    end
  end
end
