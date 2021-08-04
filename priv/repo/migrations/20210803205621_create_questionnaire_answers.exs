defmodule Picsello.Repo.Migrations.CreateQuestionnaireAnswers do
  use Ecto.Migration

  def change do
    create table(:questionnaire_answers) do
      add(:proposal_id, references(:booking_proposals), null: false)
      add(:questionnaire_id, references(:questionnaires), null: false)
      add(:answers, :map, null: false)

      timestamps()
    end

    create(index(:questionnaire_answers, [:proposal_id], unique: true))
  end
end
