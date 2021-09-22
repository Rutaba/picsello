defmodule Picsello.ViewJobTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user, session: session} do
    job = insert(:job, user: user, type: "family", package: %{shoot_count: 1})
    questionnaire = insert(:questionnaire, job_type: "family")
    insert(:shoot, job: job)

    proposal =
      insert(:proposal,
        job: job,
        deposit_paid_at: DateTime.utc_now(),
        accepted_at: DateTime.utc_now(),
        signed_at: DateTime.utc_now(),
        questionnaire: questionnaire
      )

    insert(:answer, questionnaire: questionnaire, proposal: proposal)

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
