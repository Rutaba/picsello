defmodule Picsello.CreateBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{BookingProposal, Repo, Organization}

  setup :authenticated

  setup %{user: user} do
    Mox.stub(Picsello.MockPayments, :status, fn _ -> {:ok, :charges_enabled} end)

    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    insert(:questionnaire)

    job =
      insert(:job, %{
        user: user,
        type: "newborn",
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 1,
          price: 100
        }
      })

    [job: job]
  end

  feature "user sends booking proposal", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> assert_has(css("button:disabled", text: "Send booking proposal"))
    |> click(link("Add shoot details"))
    |> fill_in(text_field("Shoot name"), with: "chute")
    |> fill_in(text_field("Shoot date"), with: "04052040\t1200P")
    |> click(option("1.5 hrs"))
    |> click(css("label", text: "On Location"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("button:not(:disabled)", text: "Send booking proposal"))
    |> click(button("Send booking proposal"))

    assert_receive {:delivered_email, email}

    path =
      email
      |> email_substitutions
      |> Map.get("url")
      |> URI.parse()
      |> Map.get(:path)

    assert "/proposals/" <> token = path

    last_proposal_id = BookingProposal.last_for_job(job.id).id

    assert {:ok, ^last_proposal_id} =
             Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: 1000)

    session
    |> assert_path("/jobs")
    |> assert_has(css(".alert", text: "booking proposal was sent"))
    |> visit("/jobs/#{job.id}")
    |> assert_has(css("p", text: "Booking proposal sent"))
  end
end