defmodule Picsello.ClientAcceptsBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo, Organization}

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

  feature "client clicks link in booking proposal email", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(checkbox("Include questionnaire", selected: true))
    |> click(button("Send booking proposal"))

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("url")

    Mox.stub(Picsello.MockPayments, :checkout_link, fn _, _, _ ->
      {:ok, "https://example.com/stripe-checkout"}
    end)

    proposal_id = Picsello.BookingProposal.last_for_job(job.id).id

    Mox.stub(Picsello.MockPayments, :construct_event, fn _, _, _ ->
      {:ok,
       %{
         type: "checkout.session.completed",
         data: %{object: %{client_reference_id: "proposal_#{proposal_id}"}}
       }}
    end)

    session
    |> visit(url)
    |> assert_has(css("h2", text: Job.name(job)))
    |> assert_has(css("button:disabled", text: "Pay 50% deposit"))
    |> click(button("Proposal TO-DO"))
    |> assert_has(definition("Package:", text: "My Package"))
    |> assert_has(definition("Total", text: "$1.00"))
    |> assert_has(
      definition("Proposal #:",
        text: Picsello.BookingProposal.last_for_job(job.id).id |> Integer.to_string()
      )
    )
    |> click(button("Accept proposal"))
    |> assert_has(button("Proposal DONE"))
    |> assert_has(css("button:disabled", text: "Pay 50% deposit"))
    |> click(button("Contract TO-DO"))
    |> assert_has(css("h3", text: "Terms and Conditions"))
    |> assert_has(button("Sign", disabled: true))
    |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
    |> wait_for_enabled_submit_button()
    |> click(button("Sign"))
    |> assert_has(button("Contract DONE"))
    |> assert_has(css("button:not(:disabled)", text: "Pay 50% deposit"))
    |> click(button("Pay 50% deposit"))
    |> assert_url_contains("stripe-checkout")
    |> post("/stripe/connect-webhooks", "", [{"stripe-signature", "love, stripe"}])
    |> visit(url)
    |> assert_has(button("50% deposit paid"))
  end

  feature "client fills out booking proposal questionnaire", %{session: session, job: job} do
    insert(:questionnaire)

    session
    |> visit("/jobs/#{job.id}")
    |> click(button("Send booking proposal"))

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("url")

    session
    |> visit(url)
    |> click(button("Proposal TO-DO"))
    |> click(button("Accept proposal"))
    |> click(button("Contract TO-DO"))
    |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
    |> wait_for_enabled_submit_button()
    |> click(button("Sign"))
    |> click(button("Questionnaire TO-DO"))
    |> click(checkbox("My partner", selected: false))
    |> click(button("cancel"))
    |> click(button("Questionnaire TO-DO"))
    |> visit(url)
    |> assert_has(css("button:disabled", text: "Pay 50% deposit"))
    |> click(button("Questionnaire TO-DO"))
    |> click(checkbox("My partner", selected: false))
    |> assert_has(css("button:disabled", text: "Save"))
    |> fill_in(text_field("why?"), with: "it's the best.")
    |> click(css("label", text: "Of course"))
    |> fill_in(text_field("Describe it"), with: "it's great.")
    |> fill_in(text_field("When"), with: "10/10/2021")
    |> fill_in(text_field("Email"), with: "email@example.com")
    |> fill_in(text_field("Phone"), with: "(255) 123-1234")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("button:not(:disabled)", text: "Pay 50% deposit"))
    |> click(button("Questionnaire DONE"))
    |> assert_has(checkbox("My partner", selected: true))
  end

  defp post(session, path, body, headers) do
    HTTPoison.post(
      PicselloWeb.Endpoint.url() <> path,
      body,
      headers ++
        [
          {"user-agent", user_agent(session)}
        ]
    )

    session
  end

  defp user_agent(session) do
    session
    |> execute_script("return navigator.userAgent;", [], &send(self(), {:user_agent, &1}))

    receive do
      {:user_agent, agent} -> agent
    end
  end
end
