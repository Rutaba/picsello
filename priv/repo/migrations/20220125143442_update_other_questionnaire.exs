defmodule Picsello.Repo.Migrations.UpdateOtherQuestionnaire do
  use Ecto.Migration

  def change do
    execute(
      """
        update questionnaires
        set questions = jsonb_set(questions, '{0,prompt}', '"Tell me about your shoot"', true)
        where job_type = 'other'
        and questions->0->>'prompt' = 'Shoot type';
      """,
      """
        update questionnaires
        set questions = jsonb_set(questions, '{0,prompt}', '"Shoot type"', true)
        where job_type = 'other'
        and questions->0->>'prompt' = 'Tell me about your shoot';
      """
    )
  end
end
