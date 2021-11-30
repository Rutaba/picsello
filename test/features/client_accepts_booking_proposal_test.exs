defmodule Picsello.ClientAcceptsBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo, Organization, BookingProposal}

  @send_email_button button("Send Email")
  @invoice_button button("Invoice")

  setup %{sessions: [photographer_session | _]} do
    user =
      insert(:user, email: "photographer@example.com", organization: %{name: "Photography LLC"})
      |> onboard!

    photographer_session |> sign_in(user)
    [user: user]
  end

  setup %{user: user} do
    Mox.stub(Picsello.MockPayments, :status, fn _ -> :charges_enabled end)

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
          base_price: 100
        },
        client: %{name: "John"},
        shoots: [
          %{
            name: "Shoot 1",
            address: "320 1st st",
            starts_at: ~U[2021-09-30 19:00:00Z],
            duration_minutes: 15
          }
        ]
      })

    [lead: lead]
  end

  describe "client accepts" do
    setup %{sessions: [photographer_session, _], lead: lead} do
      photographer_session
      |> visit("/leads/#{lead.id}")
      |> click(checkbox("Questionnaire included", selected: true))
      |> click(button("Finish booking proposal"))
      |> click(@send_email_button)

      assert_receive {:delivered_email, email}
      url = email |> email_substitutions |> Map.get("url")

      test_pid = self()

      Mox.stub(Picsello.MockPayments, :checkout_link, fn _, products, opts ->
        send(
          test_pid,
          {:checkout_linked, opts |> Enum.into(%{products: products})}
        )

        {:ok, "https://example.com/stripe-checkout"}
      end)

      proposal = BookingProposal.last_for_job(lead.id)

      [url: url, proposal: proposal]
    end

    @sessions 2
    feature "client clicks link in booking proposal email", %{
      sessions: [_, client_session],
      lead: lead,
      url: url,
      proposal: proposal
    } do
      Mox.stub(Picsello.MockPayments, :construct_event, fn metadata, _, _ ->
        {:ok,
         %{
           type: "checkout.session.completed",
           data: %{
             object: %Stripe.Session{
               client_reference_id: "proposal_#{proposal.id}",
               metadata: %{"paying_for" => metadata}
             }
           }
         }}
      end)

      Picsello.MockPayments
      |> Mox.expect(:retrieve_session, fn "{CHECKOUT_SESSION_ID}" ->
        {:ok,
         %Stripe.Session{
           client_reference_id: "proposal_#{proposal.id}",
           metadata: %{"paying_for" => "deposit"}
         }}
      end)
      |> Mox.expect(:retrieve_session, fn "{CHECKOUT_SESSION_ID}" ->
        {:ok,
         %Stripe.Session{
           client_reference_id: "proposal_#{proposal.id}",
           metadata: %{"paying_for" => "remainder"}
         }}
      end)

      client_session
      |> visit(url)
      |> assert_has(css("h2", text: Job.name(lead)))
      |> assert_disabled(@invoice_button)
      |> assert_text("Below are details for")
      |> click(button("To-Do Proposal"))
      |> assert_has(
        definition("Dated:", text: Calendar.strftime(proposal.inserted_at, "%b %d, %Y"))
      )
      |> assert_has(definition("Quote #:", text: Integer.to_string(proposal.id)))
      |> assert_has(definition("For:", text: "John"))
      |> assert_has(definition("From:", text: "Photography LLC"))
      |> assert_has(definition("Email:", text: "photographer@example.com"))
      |> assert_has(definition("Package:", text: "My Package"))
      |> assert_has(definition("Total", text: "$1.00"))
      |> assert_has(testid("shoot-title", text: "Shoot 1"))
      |> assert_has(testid("shoot-title", text: "September 30, 2021"))
      |> assert_has(testid("shoot-description", text: "15 mins starting at 7:00 pm"))
      |> assert_has(testid("shoot-description", text: "320 1st st"))
      |> click(button("Accept Quote"))
      |> assert_disabled(@invoice_button)
      |> click(button("Completed Proposal"))
      |> within_modal(&assert_has(&1, css("button", count: 1, text: "Close")))
      |> click(button("Close"))
      |> click(button("To-Do Contract"))
      |> assert_text("Terms and Conditions")
      |> assert_disabled(button("Submit"))
      |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
      |> wait_for_enabled_submit_button()
      |> click(button("Submit"))
      |> assert_has(button("Completed Contract"))
      |> take_screenshot()
      |> click(button("To-Do Invoice"))
      |> assert_has(definition("Total", text: "$1.00"))
      |> assert_has(definition("50% deposit today", text: "$0.50"))
      |> assert_has(definition("Remainder Due on Sep 30, 2021", text: "$0.50"))
      |> click(button("Pay Invoice"))
      |> assert_url_contains("stripe-checkout")

      refute proposal |> Repo.reload() |> BookingProposal.deposit_paid?()

      client_session
      |> post("/stripe/connect-webhooks", "deposit", [
        {"stripe-signature", "love, stripe"}
      ])

      assert_receive {:delivered_email, email}

      assert %{"url" => email_link, "job" => "John Newborn", "client" => "John"} =
               email |> email_substitutions()

      assert String.ends_with?(email_link, "/jobs")

      assert_receive {:checkout_linked,
                      %{
                        success_url: stripe_success_url,
                        metadata: %{"paying_for" => :deposit},
                        products: [
                          %{
                            price_data: %{
                              product_data: %{name: "John Newborn 50% deposit"},
                              unit_amount: 50
                            }
                          }
                        ]
                      }}

      assert proposal |> Repo.reload() |> BookingProposal.deposit_paid?()

      client_session
      |> visit(stripe_success_url)
      |> assert_has(css("h1", text: "Thank you"))
      |> assert_has(css("h1", text: "Your session is now booked."))
      |> click(button("Got it"))
      |> assert_text("Below are details for")
      |> click(button("To-Do Invoice"))
      |> assert_has(definition("Total", text: "$1.00"))
      |> assert_has(
        definition("Deposit Paid on #{Calendar.strftime(DateTime.utc_now(), "%b %d, %Y")}",
          text: "$0.50"
        )
      )
      |> assert_has(definition("Remainder Due on Sep 30, 2021", text: "$0.50"))
      |> click(button("Pay Invoice"))
      |> assert_url_contains("stripe-checkout")

      refute proposal
             |> Repo.reload()
             |> BookingProposal.remainder_paid?()

      client_session
      |> post("/stripe/connect-webhooks", "remainder", [
        {"stripe-signature", "love, stripe"}
      ])

      assert proposal |> Repo.reload() |> BookingProposal.remainder_paid?()

      assert_receive {:checkout_linked,
                      %{
                        success_url: stripe_success_url,
                        metadata: %{"paying_for" => :remainder},
                        products: [
                          %{
                            price_data: %{
                              product_data: %{name: "John Newborn 50% remainder"},
                              unit_amount: 50
                            }
                          }
                        ]
                      }}

      client_session
      |> visit(stripe_success_url)
      |> take_screenshot()
      |> assert_has(css("h1", text: "Paid in full."))
      |> click(button("Got it"))
      |> assert_text("Thanks for your business!")
      |> click(button("Completed Invoice"))
      |> assert_has(definition("Total", text: "$1.00"))
      |> assert_has(
        definition("Deposit Paid on #{Calendar.strftime(DateTime.utc_now(), "%b %d, %Y")}",
          text: "$0.50"
        )
      )
      |> assert_has(
        definition("Remainder Paid on #{Calendar.strftime(DateTime.utc_now(), "%b %d, %Y")}",
          text: "$0.50"
        )
      )
      |> find(testid("modal-buttons"), &assert_has(&1, css("button", count: 1)))
    end

    @sessions 2
    feature "client pays - webhook is late", %{
      sessions: [_, client_session],
      lead: lead,
      proposal: %{id: proposal_id},
      url: url
    } do
      Mox.stub(Picsello.MockPayments, :retrieve_session, fn "{CHECKOUT_SESSION_ID}" ->
        {:ok,
         %Stripe.Session{
           client_reference_id: "proposal_#{proposal_id}",
           metadata: %{"paying_for" => "deposit"}
         }}
      end)

      client_session
      |> visit(url)
      |> assert_has(css("h2", text: Job.name(lead)))
      |> click(button("To-Do Proposal"))
      |> click(button("Accept Quote"))
      |> click(button("To-Do Contract"))
      |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
      |> wait_for_enabled_submit_button()
      |> click(button("Submit"))
      |> click(button("To-Do Invoice"))
      |> click(button("Pay Invoice"))
      |> assert_url_contains("stripe-checkout")

      assert_receive {:checkout_linked, %{success_url: stripe_success_url}}

      client_session
      |> visit(stripe_success_url)
      |> assert_has(css("h1", text: "Thank you"))
      |> assert_has(css("h1", text: "Your session is now booked."))
    end
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
    |> assert_disabled(@invoice_button)
    |> click(button("To-Do Proposal"))
    |> click(button("Accept Quote"))
    |> assert_disabled(@invoice_button)
    |> click(button("To-Do Contract"))
    |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
    |> wait_for_enabled_submit_button()
    |> click(button("Submit"))
    |> assert_enabled(@invoice_button)
    |> click(button("To-Do Questionnaire"))
    |> click(checkbox("My partner", selected: false))
    |> click(button("Close"))
    |> click(button("To-Do Questionnaire"))
    |> visit(url)
    |> click(button("To-Do Questionnaire"))
    |> click(checkbox("My partner", selected: false))
    |> assert_has(css("button:disabled", text: "Save"))
    |> fill_in(text_field("why?"), with: "it's the best.")
    |> click(css("label", text: "Of course"))
    |> fill_in(text_field("Describe it"), with: "it's great.")
    |> fill_in_date(text_field("When"), with: ~D[2021-10-10])
    |> fill_in(text_field("Email"), with: "email@example.com")
    |> fill_in(text_field("Phone"), with: "(255) 123-1234")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(button("Completed Questionnaire"))
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
    |> assert_flash(:error, text: "not available")
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
