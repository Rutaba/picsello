defmodule Picsello.Repo.Migrations.RunTasksForDevSetup do
  use Ecto.Migration

  def change do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Tasks.ImportQuestionnaires.questionnaires()
      Mix.Tasks.InsertGlobalSettings.global_settings()
    end
  end
end
