defmodule Picsello.Repo.Migrations.RemoveThanksJobTemplate do
  use Ecto.Migration
  alias Picsello.{EmailAutomations}

  def change do
    pipeline = EmailAutomations.get_pipeline_by_state(:thanks_job)

    execute("""
    delete from email_presets WHERE state='thanks_job';
    """)

    execute("""
    delete from email_schedules WHERE email_automation_pipeline_id=#{pipeline.id};
    """)

    execute("""
    delete from email_schedules_history WHERE email_automation_pipeline_id=#{pipeline.id};
    """)

    execute("""
    delete from email_automation_pipelines WHERE state='thanks_job';
    """)
  end
end
