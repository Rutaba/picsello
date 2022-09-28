defmodule Picsello.CreateBookingProposalTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Repo, Organization}

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

    insert(:email_preset, job_type: lead.type, state: :booking_proposal)

    [lead: lead]
  end

  setup %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> assert_has(css("button:disabled", text: "Send proposal", count: 2))
    |> assert_disabled(button("Copy client link"))
    |> find(testid("card-Package details"), &assert_has(&1, button("Edit", count: 1)))
    |> assert_text("50% retainer and 50% on day of shoot")
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
    |> find(testid("card-Package details"), &assert_has(&1, button("Edit", count: 0)))

    assert_receive {:delivered_email, email}

    path =
      email
      |> email_substitutions
      |> Map.get("button")
      |> Map.get(:url)
      |> URI.parse()
      |> Map.get(:path)

    [session: session, path: path]
  end

  feature "Show schedule anchor tag is disabled when you visit client side's proposal screen or you've not accepted the proposal yet",
          %{
            session: session,
            path: path
          } do
    session
    |> visit(path)
    |> assert_has(css("a[disabled]"))
    |> click(button("Review your proposal", count: 1))
    |> click(button("Accept Quote", count: 1))
    |> assert_has(css("a[disabled]"))
  end

  feature "Show schedule anchor tag is visible when you accept the contract and click it to open schedule popup",
          %{
            session: session,
            path: path
          } do
    session
    |> visit(path)
    |> click(button("Review your proposal", count: 1))
    |> click(button("Accept Quote", count: 1))
    |> click(button("Read and agree to your contract", count: 1))
    |> fill_in(text_field("Type your full legal name"), with: "test-name")
    |> wait_for_enabled_submit_button()
    |> force_simulate_click(css(".accept-contract"))
    |> assert_has(css("*[disabled]", count: 0))
    |> click(css(".schedule-popup-link"))
    |> assert_text("Payment schedule")
  end
end
