defmodule Picsello.ClientAcceptsBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo, Organization}

  @send_email_button button("Send Email")

  setup %{sessions: [photographer_session | _]} do
    user = insert(:user) |> onboard!
    photographer_session |> sign_in(user)
    [user: user]
  end

  setup %{user: user} do
    Mox.stub(Picsello.MockPayments, :status, fn _ -> {:ok, :charges_enabled} end)

    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    lead =
      insert(:lead, %{
        user: user,
        type: "newborn",
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 1,
          price: 100
        },
        client: %{name: "John"},
        shoots: [%{}]
      })

    [lead: lead]
  end

  @sessions 2
  feature "client clicks link in booking proposal email", %{
    sessions: [photographer_session, client_session],
    lead: lead
  } do
    photographer_session
    |> visit("/leads/#{lead.id}")
    |> click(checkbox("Questionnaire included", selected: true))
    |> click(button("Finish booking proposal"))
    |> click(@send_email_button)

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("url")

    test_pid = self()

    Mox.stub(Picsello.MockPayments, :checkout_link, fn _, _, return_urls ->
      send(test_pid, {:success_url, Keyword.get(return_urls, :success_url)})

      {:ok, "https://example.com/stripe-checkout"}
    end)

    proposal_id = Picsello.BookingProposal.last_for_job(lead.id).id

    Mox.stub(Picsello.MockPayments, :construct_event, fn _, _, _ ->
      {:ok,
       %{
         type: "checkout.session.completed",
         data: %{object: %{client_reference_id: "proposal_#{proposal_id}"}}
       }}
    end)

    client_session
    |> visit(url)
    |> assert_has(css("h2", text: Job.name(lead)))
    |> assert_has(css("button:disabled", text: "Pay 50% deposit"))
    |> click(button("Proposal TO-DO"))
    |> assert_has(definition("Package:", text: "My Package"))
    |> assert_has(definition("Total", text: "$1.00"))
    |> assert_has(
      definition("Proposal #:",
        text: Picsello.BookingProposal.last_for_job(lead.id).id |> Integer.to_string()
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

    assert_receive {:delivered_email, email}

    assert %{"url" => email_link, "job" => "John Newborn", "client" => "John"} =
             email |> email_substitutions()

    assert String.ends_with?(email_link, "/jobs")

    assert_receive {:success_url, stripe_success_url}

    client_session
    |> visit(stripe_success_url)
    |> assert_has(css("h1", text: "Thank you"))
    |> click(button("Whoo hoo!"))
    |> assert_has(button("50% deposit paid"))
    # reload and the message is not displayed again
    |> visit(stripe_success_url)
    |> assert_has(css("h1", text: "Thank you"))
    |> visit(client_session |> current_url())
    |> assert_has(button("50% deposit paid"))
  end

  @sessions 2
  feature "client fills out booking proposal questionnaire", %{
    sessions: [photographer_session, client_session],
    lead: lead
  } do
    insert(:questionnaire)

    photographer_session
    |> visit("/leads/#{lead.id}")
    |> click(button("Finish booking proposal"))
    |> click(@send_email_button)

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("url")

    client_session
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

  @sessions 2
  feature "client accesses proposal for archived lead", %{
    sessions: [photographer_session, client_session],
    lead: lead
  } do
    insert(:questionnaire)

    photographer_session
    |> visit("/leads/#{lead.id}")
    |> click(button("Finish booking proposal"))
    |> click(@send_email_button)

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("url")

    lead |> Job.archive_changeset() |> Repo.update!()

    client_session
    |> visit(url)
    |> assert_has(css(".alert-error", text: "not available"))
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
