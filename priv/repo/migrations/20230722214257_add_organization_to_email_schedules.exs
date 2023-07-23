defmodule Picsello.Repo.Migrations.AddOrganizationToEmailSchedules do
  use Ecto.Migration

  def up do
    alter table(:email_schedules) do
      add(:organization_id, references(:organizations, on_delete: :nothing))
    end
  end

  def down do
    alter table(:email_schedules) do
      remove(:organization_id)
    end
  end
end
