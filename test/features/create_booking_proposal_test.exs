defmodule Picsello.CreateBookingProposalTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{
    Questionnaire.Answer,
    BookingProposal,
    Repo,
    Organization,
    ClientMessage,
    Questionnaire,
    PaymentSchedule
  }

  import Ecto.Query

  @send_email_button button("Send Email")

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)

    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    questionnaire = insert(:questionnaire)

    lead =
      insert(:lead, %{
        user: user,
        type: "newborn",
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 1,
          base_price: 100,
          questionnaire_template_id: questionnaire.id
        }
      })

    insert(:email_preset, job_type: lead.type, state: :booking_proposal)

    [lead: lead]
  end

  feature "user sends booking proposal", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> assert_has(css("button:disabled", text: "Send proposal", count: 2))
    |> assert_disabled(button("Copy client link"))
    |> find(testid("card-Package details"), &click(&1, button("Edit", count: 1)))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_text("$0.50 to To Book, $0.50 to Day Before Shoot")
    |> assert_text("Add all shoots")
    |> click(button("Add shoot details"))
    |> fill_in(text_field("Shoot Title"), with: "chute")
    |> fill_in(text_field("Shoot Date"), with: "04052040\t1200P")
    |> find(select("Shoot Duration"), &click(&1, option("1.5 hrs")))
    |> find(select("Shoot Location"), &click(&1, option("On Location")))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("button:not(:disabled)", text: "Send proposal", count: 2))
    |> click(button("Send proposal", count: 2, at: 1))
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
    assert [questionnaire] = Repo.all(Questionnaire)
    assert client_message.job_id == proposal.job_id
    assert [deposit_payment, remainder_payment] = Repo.all(PaymentSchedule)
    assert deposit_payment.job_id == proposal.job_id
    assert remainder_payment.job_id == proposal.job_id
    assert questionnaire.id == proposal.questionnaire_id

    path =
      email
      |> email_substitutions
      |> Map.get("button")
      |> Map.get(:url)
      |> URI.parse()
      |> Map.get(:path)

    assert "/proposals/" <> token = path

    %{id: last_proposal_id} = proposal = BookingProposal.last_for_job(lead.id)

    assert {:ok, ^last_proposal_id} =
             Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: 1000)

    session
    |> assert_text("Proposal sent")
    |> assert_text("Awaiting acceptance")
    |> click(button("View proposal"))
    |> find(testid("modal-buttons"), &assert_has(&1, css("button", count: 1)))
    |> click(button("Close"))
    |> click(testid("view-contract"))
    |> assert_disabled(text_field("Type your full legal name"))
    |> click(button("Close"))
    |> click(testid("view-questionnaire"))
    |> all(css("input, textarea, select"))
    |> Enum.reduce(session, fn el, session -> assert_disabled(session, el) end)

    # payment is disabled for photograper even if client completed other steps
    [:accept, :sign, :questionnaire]
    |> Enum.reduce(proposal, &complete_proposal(&2, &1))

    session
    |> visit(current_path(session))
    |> assert_text("Questionnaire answered")
    |> assert_text("Pending payment")
    |> find(testid("card-Package details"), &assert_has(&1, button("Edit", count: 0)))
    |> click(button("Copy client link"))
    |> assert_text("Copied!")

    [overdue_schedule, upcoming_schedule] = Repo.all(PaymentSchedule)

    session
    |> visit(path)
    |> click(css("a", text: "Show schedule"))
    |> assert_text("Payment schedule")
    |> assert_text("Overdue #{overdue_schedule.due_at |> Calendar.strftime("%B %-d, %Y")}")
    |> assert_has(button("Pay overdue invoice"))
    |> assert_text("Upcoming #{upcoming_schedule.due_at |> Calendar.strftime("%B %-d, %Y")}")

    Repo.update_all(PaymentSchedule, set: [paid_at: Timex.now()])
    [overdue_schedule, upcoming_schedule] = Repo.all(PaymentSchedule)

    session
    |> visit(path)
    |> assert_text("Completed")
    |> click(css("a", text: "Show schedule"))
    |> refute_has(button("Pay overdue invoice"))
    |> refute_has(button("Pay upcoming invoice"))
    |> assert_text("Paid #{overdue_schedule.paid_at |> Calendar.strftime("%B %-d, %Y")}")
    |> assert_text("Paid #{upcoming_schedule.paid_at |> Calendar.strftime("%B %-d, %Y")}")

    payment = Repo.one(from(p in PaymentSchedule, order_by: [desc: p.id], limit: 1))
    Repo.update(Ecto.Changeset.change(payment, paid_at: nil))

    session
    |> visit(path)
    |> assert_text("Next payment due: #{payment.due_at |> Calendar.strftime("%m/%d/%Y")}")
    |> click(css("a", text: "Show schedule"))
    |> assert_has(button("Pay upcoming invoice"))

    Repo.delete(payment)

    session
    |> visit(path)
    |> refute_has(css("a", text: "Show schedule"))

    [path: path]
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
