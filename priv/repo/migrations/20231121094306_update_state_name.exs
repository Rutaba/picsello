defmodule Picsello.Repo.Migrations.UpdateStateName do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE email_presets SET state = 'balance_due_offline' WHERE state = 'offline_payment';
    """)

    execute("""
    UPDATE email_automation_pipelines SET state = 'balance_due_offline' WHERE state = 'offline_payment';
    """)
  end
end
