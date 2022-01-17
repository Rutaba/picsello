defmodule Picsello.QuestionnaireTest do
  use Picsello.DataCase, async: true

  alias Picsello.{Repo, Questionnaire, Job}

  describe "for_job" do
    setup do
      Mix.Tasks.ImportQuestionnaires.run(nil)
    end

    test "when job type is different than other" do
      assert %{job_type: "family"} = Questionnaire.for_job(%Job{type: "family"}) |> Repo.one()
    end

    test "when job type is other" do
      assert %{job_type: "other"} = Questionnaire.for_job(%Job{type: "other"}) |> Repo.one()
    end

    test "when job type doesn't exist then falls back to other" do
      assert %{job_type: "other"} = Questionnaire.for_job(%Job{type: "event"}) |> Repo.one()
    end
  end
end
