defmodule Mix.Tasks.ImportQuestionnaires do
  @moduledoc false

  use Mix.Task

  alias Picsello.{Questionnaire.Question, Questionnaire, Repo}

  @shortdoc "import questionnaires"
  def run(_) do
    Mix.Task.run("app.start")

    Questionnaire.changeset(%Questionnaire{}, %{
      questions: [
        %{
          prompt: "Style of wedding",
          type: :multiselect,
          options: [
            "Elegant",
            "Modern",
            "Rustic Vibe",
            "Vintage",
            "Natural / Outdoorsy",
            "DIY",
            "Nerdy"
          ]
        },
        %{
          prompt: "Anything else you think we should know about you and your wedding day?",
          type: :text
        }
      ],
      job_type: "wedding"
    })
    |> Repo.insert!()
  end
end
