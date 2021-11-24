defmodule Picsello.CreateBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Questionnaire.Answer, BookingProposal, Repo, Organization, ClientMessage}

  @send_email_button button("Send Email")

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    Mox.stub(Picsello.MockPayments, :status, fn _ -> :charges_enabled end)

    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    insert(:questionnaire)

    lead =
      insert(:lead, %{
        user: user,
        type: "newborn",
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 1,
          base_price: 100
        }
      })

    [lead: lead]
  end

  feature "user sends booking proposal", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> assert_has(css("button:disabled", text: "Finish booking proposal"))
    |> assert_text("You haven’t sent a proposal yet.")
    |> click(button("Add shoot details"))
    |> fill_in(text_field("Shoot Title"), with: "chute")
    |> fill_in(text_field("Shoot Date"), with: "04052040\t1200P")
    |> find(select("Shoot Duration"), &click(&1, option("1.5 hrs")))
    |> find(select("Shoot Location"), &click(&1, option("On Location")))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("button:not(:disabled)", text: "Finish booking proposal"))
    |> click(button("Finish booking proposal"))
    |> fill_in(text_field("Subject line"), with: "")
    |> assert_has(css("label", text: "Subject line can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Subject"), with: "Proposal from me")
    |> wait_for_enabled_submit_button()
    |> click(@send_email_button)
    |> assert_has(css("h1", text: "Email sent"))
    |> click(button("Close"))

    assert_receive {:delivered_email, email}

    assert "Proposal from me" = email |> email_substitutions |> Map.get("subject")

    assert [proposal] = Repo.all(BookingProposal)
    assert [client_message] = Repo.all(ClientMessage)
    assert client_message.job_id == proposal.job_id

    path =
      email
      |> email_substitutions
      |> Map.get("url")
      |> URI.parse()
      |> Map.get(:path)

    assert "/proposals/" <> token = path

    %{id: last_proposal_id} = proposal = BookingProposal.last_for_job(lead.id)

    assert {:ok, ^last_proposal_id} =
             Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: 1000)

    session
    |> assert_text("Proposal sent")
    |> click(link("Proposal"))
    |> find(testid("modal-buttons"), &assert_has(&1, css("button", count: 1)))
    |> click(button("Close"))
    |> click(link("Standard Contract"))
    |> assert_disabled(text_field("Type your full legal name"))
    |> click(button("Close"))
    |> click(link("Questionnaire"))
    |> all(css("input, textarea, select"))
    |> Enum.reduce(session, fn el, session -> assert_disabled(session, el) end)

    # payment is disabled for photograper even if client completed other steps
    [:accept, :sign, :questionnaire]
    |> Enum.reduce(proposal, &complete_proposal(&2, &1))

    session
    |> visit(current_path(session))
    |> assert_has(link("Proposal", text: "Accepted"))
    |> assert_has(link("Contract", text: "Signed"))
    |> assert_has(link("Questionnaire", text: "Completed"))

    session
    |> click(button("Client Link"))
    |> assert_text("Copied!")
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
end
