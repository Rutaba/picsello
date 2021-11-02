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
    |> within_modal(&assert_text(&1, "Accepted on"))
  end

  feature "user views contract", %{session: session} do
    session
    |> click(css("a[title='Standard Contract']"))
    |> assert_has(css(".modal", text: "Signed on"))
  end

  feature "user views questionnaire", %{session: session} do
    session
    |> click(css("a[title='Questionnaire']"))
    |> assert_has(css(".modal", text: "Questionnaire answered"))
  end

  feature "user adds notes", %{session: session} do
    session
    |> assert_has(definition("Private Notes", text: "Click edit to add a note"))
    |> find(testid("notes"), &click(&1, button("Edit")))
    |> fill_in(text_field("Private Notes"), with: "here are my private notes")
    |> click(button("Save"))
    |> assert_has(definition("Private Notes", text: "here are my private notes"))
    |> find(testid("notes"), &click(&1, button("View")))
    |> assert_has(css(".modal", text: "here are my private notes"))
    |> find(css(".modal"), &click(&1, button("Edit")))
    |> assert_value(text_field("Private Notes"), "here are my private notes")
    |> find(css(".modal"), &click(&1, button("Clear")))
    |> assert_value(text_field("Private Notes"), "")
    |> fill_in(text_field("Private Notes"), with: "here are my 2nd private notes")
    |> click(button("Save"))
    |> assert_has(definition("Private Notes", text: "here are my 2nd private notes"))
  end
end
