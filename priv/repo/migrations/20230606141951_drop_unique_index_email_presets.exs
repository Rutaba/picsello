defmodule Picsello.Repo.Migrations.DropUniqueIndexEmailPresets do
  use Ecto.Migration

  @table :email_presets
  def up do
    drop(constraint(@table, "job_must_have_job_type"))
    execute("drop index email_presets_job_type_job_state_name_index")

    if System.get_env("MIX_ENV") != "prod" do
      flush()
      Mix.Tasks.ImportEmailAutomationPipelines.insert_email_pipelines()
    end
  end

  def down do
    create(
      constraint(@table, "job_must_have_job_type",
        check: "((type = 'job')::integer + (job_type is not null)::integer) % 2 = 0"
      )
    )
  end
end
