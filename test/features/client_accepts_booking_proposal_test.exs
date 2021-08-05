defmodule Picsello.ClientAcceptsBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo, Organization}

  setup :authenticated

  setup %{user: user, session: session} do
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

    session
    |> visit("/jobs/#{job.id}")
    |> click(button("Send booking proposal"))

    assert_receive {:delivered_email, email}

    [job: job, url: email |> email_substitutions |> Map.get("url")]
  end

  feature "client clicks link in booking proposal email", %{session: session, url: url, job: job} do
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
    |> click(button("Contract TO-DO"))
    |> assert_has(css("h3", text: "Terms and Conditions"))
    |> assert_has(button("Sign", disabled: true))
    |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
    |> wait_for_enabled_submit_button()
    |> click(button("Sign"))
    |> assert_has(button("Contract DONE"))
    |> click(button("Pay 50% deposit"))
    |> assert_url_contains("stripe-checkout")
    |> post("/stripe/connect-webhooks", "", [{"stripe-signature", "love, stripe"}])
    |> visit(url)
    |> assert_has(button("50% deposit paid"))
  end

  feature "client fills out booking proposal questionnaire", %{
    session: session,
    url: url
  } do
    insert(:questionnaire)

    session
    |> visit(url)
    |> click(button("Questionnaire TO-DO"))
    |> click(checkbox("My partner", checked: false))
    |> click(button("cancel"))
    |> click(button("Questionnaire TO-DO"))
    |> visit(url)
    |> click(button("Questionnaire TO-DO"))
    |> click(checkbox("My partner", checked: false))
    |> assert_has(css("button:disabled", text: "Save"))
    |> fill_in(text_field("why?"), with: "it's the best.")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(button("Questionnaire DONE"))
    |> assert_has(checkbox("My partner", checked: true))
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
