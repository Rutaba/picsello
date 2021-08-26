defmodule Picsello.CreateBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Questionnaire.Answer, BookingProposal, Repo, Organization}

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
    |> visit("/leads/#{job.id}")
    |> assert_has(css("button:disabled", text: "Finish booking proposal"))
    |> click(button("Add shoot details"))
    |> fill_in(text_field("Shoot name"), with: "chute")
    |> fill_in(text_field("Shoot date"), with: "04052040\t1200P")
    |> click(option("1.5 hrs"))
    |> click(css("label", text: "On Location"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("button:not(:disabled)", text: "Finish booking proposal"))
    |> click(button("Finish booking proposal"))
    |> click(button("Send email"))
    |> assert_has(css("h1", text: "Email sent"))
    |> click(button("Close"))

    assert_receive {:delivered_email, email}

    path =
      email
      |> email_substitutions
      |> Map.get("url")
      |> URI.parse()
      |> Map.get(:path)

    assert "/proposals/" <> token = path

    %{id: last_proposal_id} = proposal = BookingProposal.last_for_job(job.id)

    assert {:ok, ^last_proposal_id} =
             Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: 1000)

    session
    |> assert_has(css("p", text: "Booking proposal sent"))
    |> click(button("View booking proposal"))
    |> click(button("Proposal"))
    |> assert_disabled(button("Accept proposal"))
    |> click(button("cancel"))
    |> click(button("Contract"))
    |> assert_disabled(text_field("Type your full legal name"))
    |> assert_disabled(button("Sign"))
    |> click(button("cancel"))
    |> click(button("Questionnaire"))
    |> all(css("input, textarea, select"))
    |> Enum.reduce(session, fn el, session -> assert_disabled(session, el) end)

    # payment is disabled for photograper even if client completed other steps
    [:accept, :sign, :questionnaire]
    |> Enum.reduce(proposal, &complete_proposal(&2, &1))

    session
    |> visit(current_path(session))
    |> assert_has(button("Proposal", text: "DONE"))
    |> assert_has(button("Contract", text: "DONE"))
    |> assert_has(button("Questionnaire", text: "DONE"))
    |> assert_disabled(button("Pay 50% deposit"))
  end

  defp complete_proposal(proposal, :accept),
    do: proposal |> BookingProposal.accept_changeset() |> Repo.update!()

  defp complete_proposal(proposal, :sign),
    do:
      proposal
      |> BookingProposal.sign_changeset(%{"signed_legal_name" => "Elizabeth"})
      |> Repo.update!()

  defp complete_proposal(%{id: id, questionnaire_id: questionnaire_id}, :questionnaire),
    do:
      Answer.changeset(%Answer{}, %{
        proposal_id: id,
        questionnaire_id: questionnaire_id,
        answers: []
      })
      |> Repo.insert!()

  def assert_disabled(session, %Element{} = el) do
    disabled = session |> all(css("*:disabled"))

    assert Enum.member?(disabled, el)

    session
  end

  def assert_disabled(session, %Query{} = query),
    do: assert_disabled(session, session |> find(query))
end
