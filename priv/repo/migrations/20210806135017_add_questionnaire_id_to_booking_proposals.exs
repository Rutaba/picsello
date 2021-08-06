defmodule Picsello.Repo.Migrations.AddQuestionnaireIdToBookingProposals do
  use Ecto.Migration

  def change do
    alter table(:booking_proposals) do
      add(:questionnaire_id, references(:questionnaires, on_delete: :nothing))
    end

    create(index(:booking_proposals, [:questionnaire_id]))
  end
end
