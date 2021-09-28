defmodule Picsello.ViewJobTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Repo, BookingProposal}
  import Ecto.Query

  def with_completed_questionnaire(
        %BookingProposal{job: %Ecto.Association.NotLoaded{}} = proposal
      ),
      do: proposal |> Repo.preload(:job) |> with_completed_questionnaire()

  def with_completed_questionnaire(
        %BookingProposal{id: proposal_id, job: %{type: job_type}} = proposal
      ) do
    questionnaire = insert(:questionnaire, job_type: job_type)

    insert(:answer, questionnaire: questionnaire, proposal_id: proposal_id)

    Repo.update_all(from(proposal in BookingProposal, where: proposal.id == ^proposal_id),
      set: [questionnaire_id: questionnaire.id]
    )

    proposal
  end

  setup :onboarded
  setup :authenticated

  setup %{user: user, session: session} do
    %{booking_proposals: [proposal]} =
      job =
      insert(:lead, user: user)
      |> promote_to_job()
      |> Repo.preload(:booking_proposals)

    proposal |> with_completed_questionnaire()

    session
    |> visit("/jobs/#{job.id}")

    [user: user]
  end

  feature "user views proposal details", %{session: session} do
    session
    |> click(css("a[title='Proposal']"))
    |> assert_has(css(".modal", text: "Proposal accepted"))
  end

  feature "user views contract", %{session: session} do
    session
    |> click(css("a[title='Standard Contract']"))
    |> assert_has(css(".modal", text: "Contract signed"))
  end

  feature "user views questionnaire", %{session: session} do
    session
    |> click(css("a[title='Questionnaire']"))
    |> assert_has(css(".modal", text: "Questionnaire answered"))
  end
end
