defmodule Picsello.CreateBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{BookingProposal, Repo, Organization}

  setup :authenticated

  setup %{user: user} do
    Mox.stub(Picsello.MockPayments, :status, fn _ -> {:ok, :charges_enabled} end)

    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    job =
      insert(:job, %{
        user: user,
        type: "newborn",
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 1,
          price: 100
        },
        shoots: [%{}]
      })

    [job: job]
  end

  feature "user sends booking proposal", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(button("Send Booking Proposal"))

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
