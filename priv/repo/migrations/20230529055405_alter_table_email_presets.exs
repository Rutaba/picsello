defmodule Picsello.Repo.Migrations.AlterTableEmailPresets do
  use Ecto.Migration
  
  @table "email_presets"
  def change do
    alter table(@table) do
      add(:is_default, :boolean, null: false)
      add(:private_name, :string)
      add(:email_automation_setting_id, references(:email_automation_settings, on_delete: :nothing))
    end
  end
end
