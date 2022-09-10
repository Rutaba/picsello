defmodule Picsello.ClientAcceptsBookingProposalTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo, Organization, BookingProposal, PaymentSchedule, Package}

  @send_email_button button("Send Email")
  @invoice_button button("Invoice")
  @send_proposal_button button("Send proposal", count: 2, at: 1)

  setup %{sessions: [photographer_session | _]} do
    user =
      insert(:user,
        email: "photographer@example.com",
        organization: params_for(:organization, name: "Photography LLC")
      )
      |> onboard!

    photographer_session |> sign_in(user)
    [user: user]
  end

  setup %{user: user} do
    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)

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
          base_multiplier: 0.8,
          base_price: 100
        },
        client: %{name: "John"},
        shoots: [
          %{
            name: "Shoot 1",
            address: "320 1st st",
            starts_at: ~U[2029-09-30 19:00:00Z],
            duration_minutes: 15
          }
        ]
      })

    insert(:email_preset, job_type: lead.type, state: :lead)

    insert(:email_preset,
      job_type: lead.type,
      state: :booking_proposal,
      subject_template: "here is what I propose",
      body_template: "let us party."
    )

    [lead: lead]
  end

  describe "client accepts" do
    setup %{sessions: [photographer_session, _], lead: lead} do
      photographer_session
      |> visit("/leads/#{lead.id}")
      |> click(checkbox("Questionnaire included", selected: true))
      |> click(@send_proposal_button)
      |> assert_has(@send_email_button)
      |> refute_has(select("Select email preset"))
      |> assert_value(text_field("Subject line"), "here is what I propose")
      |> assert_has(css(".editor", text: "let us party."))
      |> click(@send_email_button)
      |> click(button("Close"))
      |> find(
        testid("questionnaire"),
        &assert_text(&1, "Questionnaire wasn't included in the proposal")
      )

      assert_receive {:delivered_email, email}
      url = email |> email_substitutions |> Map.get("button") |> Map.get(:url)

      test_pid = self()

      Mox.stub(Picsello.MockPayments, :create_session, fn params, opts ->
        send(
          test_pid,
          {:checkout_linked, opts |> Enum.into(params)}
        )

        {:ok,
         %{
           url:
             PicselloWeb.Endpoint.struct_url()
             |> Map.put(:fragment, "stripe-checkout")
             |> URI.to_string(),
           payment_intent: "new_intent_id",
           id: "new_session_id"
         }}
      end)

      proposal = BookingProposal.last_for_job(lead.id)

      [url: url, proposal: proposal]
    end

    @sessions 2
    feature "client clicks link in booking proposal email", %{
      lead: lead,
      proposal: proposal,
      sessions: [photographer_session, client_session],
      url: url,
      user: user
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

      [deposit_payment, remainder_payment] = Picsello.PaymentSchedules.payment_schedules(lead)

      Picsello.MockPayments
      |> Mox.expect(:retrieve_session, 2, fn "{CHECKOUT_SESSION_ID}", _opts ->
        {:ok,
         %Stripe.Session{
           client_reference_id: "proposal_#{proposal.id}",
           metadata: %{"paying_for" => deposit_payment.id}
         }}
      end)
      |> Mox.expect(:create_customer, fn params, [connect_account: "stripe_id"] ->
        assert params == lead.client |> Map.take([:email, :name])

        {:ok, %Stripe.Customer{id: "stripe-customer-id"}}
      end)

      client_session
      |> visit(url)
      |> assert_has(css("h2", text: "Welcome."))
      |> assert_disabled(@invoice_button)
      |> assert_text("Let’s get your shoot booked")
      |> click(link("Message Photography LLC"))
      |> fill_in(css(".editor > div"), with: "actual message")
      |> wait_for_enabled_submit_button()
      |> click(button("Send"))
      |> assert_text("Your message has been sent")
      |> click(button("Close"))

      assert_receive {:delivered_email, email}
      %{"subject" => subject, "body" => body} = email |> email_substitutions
      assert "You’ve got mail!" = subject
      assert body =~ "You have received a reply from John!"

      client_session
      |> click(button("To-Do Review your proposal"))
      |> assert_has(
        definition("Dated:", text: Calendar.strftime(proposal.inserted_at, "%b %d, %Y"))
      )
      |> assert_has(definition("Quote #:", text: Integer.to_string(proposal.id)))
      |> assert_has(definition("For:", text: "John"))
      |> assert_has(definition("From:", text: "Photography LLC"))
      |> assert_has(definition("Email:", text: "photographer@example.com"))
      |> assert_has(definition("Package:", text: "My Package"))
      |> assert_has(definition("Session fee", text: "$1.00"))
      |> assert_has(definition("Discount", text: "20%"))
      |> assert_has(definition("Total", text: "$0.80"))
      |> assert_has(testid("shoot-title", text: "Shoot 1"))
      |> assert_has(testid("shoot-title", text: "September 30, 2029"))
      |> assert_has(testid("shoot-description", text: "15 mins starting at 7:00 pm"))
      |> assert_has(testid("shoot-description", text: "320 1st st"))
      |> click(button("Accept Quote"))
      |> assert_disabled(@invoice_button)
      |> click(button("Completed Review your proposal"))
      |> within_modal(&assert_has(&1, css("button", count: 1, text: "Close")))
      |> click(button("Close"))
      |> click(button("To-Do Read and agree to your contract"))
      |> assert_text("Terms and Conditions")
      |> assert_text("#{lead.package.turnaround_weeks} week")
      |> assert_text(
        "laws of the State of #{PicselloWeb.Gettext.dyn_gettext(user.onboarding.state)}"
      )
      |> assert_disabled(button("Accept Contract"))
      |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
      |> wait_for_enabled_submit_button()
      |> click(button("Accept Contract"))
      |> assert_has(button("Completed Read and agree to your contract"))
      |> click(button("To-Do Pay your retainer"))
      |> assert_has(definition("Discount", text: "20%"))
      |> assert_has(definition("Total", text: "$0.80"))
      |> assert_has(definition("50% retainer due today", text: "$0.40"))
      |> assert_has(definition("50% remainder due on Sep 29, 2029", text: "$0.40"))
      |> click(button("Pay Invoice"))
      |> assert_url_contains("stripe-checkout")

      refute deposit_payment |> Repo.reload() |> then(&PaymentSchedule.paid?/1)

      client_session
      |> post("/stripe/connect-webhooks", "#{deposit_payment.id}", [
        {"stripe-signature", "love, stripe"}
      ])

      assert_receive {:delivered_email, email}
      %{"subject" => subject, "body" => body} = email |> email_substitutions
      assert "John just completed their booking proposal!" = subject
      assert body =~ "John completed their proposal."

      deposit_payment_id = deposit_payment.id

      assert_receive {:checkout_linked,
                      %{
                        success_url: stripe_success_url,
                        metadata: %{"paying_for" => ^deposit_payment_id},
                        automatic_tax: %{enabled: true},
                        payment_intent_data: %{setup_future_usage: "off_session"},
                        line_items: [
                          %{
                            price_data: %{
                              product_data: %{
                                name: "John Newborn 50% retainer",
                                tax_code: "txcd_20030000"
                              },
                              unit_amount: 40,
                              tax_behavior: "exclusive"
                            }
                          }
                        ]
                      }}

      assert deposit_payment |> Repo.reload() |> PaymentSchedule.paid?()

      client_session
      |> visit(stripe_success_url)
      |> assert_has(css("h1", text: "Thank you"))
      |> assert_has(css("h1", text: "Your session is now booked."))
      |> click(button("Got it"))
      |> assert_text("Let’s get your shoot booked")
      |> click(button("Pay your invoice"))
      |> assert_has(definition("Total", text: "$0.80"))
      |> assert_has(
        definition("50% retainer paid on #{Calendar.strftime(DateTime.utc_now(), "%b %d, %Y")}",
          text: "$0.40"
        )
      )
      |> assert_has(definition("50% remainder due on Sep 29, 2029", text: "$0.40"))
      |> click(button("Pay Invoice"))
      |> assert_url_contains("stripe-checkout")

      refute remainder_payment |> Repo.reload() |> PaymentSchedule.paid?()

      client_session
      |> post("/stripe/connect-webhooks", "#{remainder_payment.id}", [
        {"stripe-signature", "love, stripe"}
      ])

      assert remainder_payment |> Repo.reload() |> PaymentSchedule.paid?()
      remainder_payment_id = remainder_payment.id

      assert_receive {:checkout_linked,
                      %{
                        success_url: stripe_success_url,
                        metadata: %{"paying_for" => ^remainder_payment_id},
                        automatic_tax: %{enabled: true},
                        line_items: [
                          %{
                            price_data: %{
                              product_data: %{
                                name: "John Newborn 50% remainder",
                                tax_code: "txcd_20030000"
                              },
                              unit_amount: 40,
                              tax_behavior: "exclusive"
                            }
                          }
                        ]
                      }}

      client_session
      |> visit(stripe_success_url)
      |> assert_has(css("h1", text: "Paid in full."))
      |> click(button("Got it"))
      |> assert_text("Your session fee has been paid in full")
      |> click(button("Completed Pay your invoice"))
      |> assert_has(definition("Total", text: "$0.80"))
      |> assert_has(
        definition("50% retainer paid on #{Calendar.strftime(DateTime.utc_now(), "%b %d, %Y")}",
          text: "$0.40"
        )
      )
      |> assert_has(
        definition("50% remainder paid on #{Calendar.strftime(DateTime.utc_now(), "%b %d, %Y")}",
          text: "$0.40"
        )
      )
      |> find(testid("modal-buttons"), &assert_has(&1, css("button", count: 1)))

      photographer_session
      |> click(button("Go to inbox"))
      |> assert_text("actual message")
    end

    @sessions 2
    feature "client pays - webhook is late", %{
      sessions: [photographer_session, client_session],
      lead: lead,
      proposal: %{id: proposal_id},
      url: url
    } do
      [deposit_payment | _] = Picsello.PaymentSchedules.payment_schedules(lead)

      Picsello.MockPayments
      |> Mox.stub(:retrieve_session, fn "{CHECKOUT_SESSION_ID}", _opts ->
        {:ok,
         %Stripe.Session{
           client_reference_id: "proposal_#{proposal_id}",
           metadata: %{"paying_for" => deposit_payment.id}
         }}
      end)
      |> Mox.expect(:create_customer, fn params, [connect_account: "stripe_id"] ->
        assert params == Map.take(lead.client, [:email, :name])
        {:ok, %Stripe.Customer{id: "stripe-customer-id"}}
      end)

      client_session
      |> visit(url)
      |> assert_has(css("h2", text: "Welcome."))
      |> click(button("To-Do Review your proposal"))
      |> click(button("Accept Quote"))
      |> click(button("To-Do Read and agree to your contract"))
      |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
      |> wait_for_enabled_submit_button()
      |> click(button("Accept Contract"))
      |> click(button("To-Do Pay your retainer"))
      |> click(button("Pay Invoice"))
      |> assert_url_contains("stripe-checkout")

      assert_receive {:checkout_linked, %{success_url: stripe_success_url}}

      client_session
      |> visit(stripe_success_url)
      |> assert_has(css("h1", text: "Thank you"))
      |> assert_has(css("h1", text: "Your session is now booked."))

      photographer_session |> visit("/leads/#{lead.id}") |> assert_path("/jobs/#{lead.id}")
    end

    @sessions 2
    feature "client pays - expires previous session", %{
      sessions: [_photographer_session, client_session],
      lead: lead,
      proposal: %{id: proposal_id},
      url: url
    } do
      [deposit_payment | _] = Picsello.PaymentSchedules.payment_schedules(lead)

      deposit_payment
      |> Picsello.PaymentSchedule.stripe_ids_changeset("old_intent_id", "old_session_id")
      |> Repo.update()

      Picsello.MockPayments
      |> Mox.stub(:expire_session, fn "old_session_id", _opts ->
        {:ok, %Stripe.Session{}}
      end)
      |> Mox.stub(:retrieve_session, fn "{CHECKOUT_SESSION_ID}", _opts ->
        {:ok,
         %Stripe.Session{
           client_reference_id: "proposal_#{proposal_id}",
           metadata: %{"paying_for" => deposit_payment.id}
         }}
      end)
      |> Mox.expect(:create_customer, fn params, [connect_account: "stripe_id"] ->
        assert params == Map.take(lead.client, [:email, :name])
        {:ok, %Stripe.Customer{id: "stripe-customer-id"}}
      end)

      client_session
      |> visit(url)
      |> assert_has(css("h2", text: "Welcome."))
      |> click(button("To-Do Review your proposal"))
      |> click(button("Accept Quote"))
      |> click(button("To-Do Read and agree to your contract"))
      |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
      |> wait_for_enabled_submit_button()
      |> click(button("Accept Contract"))
      |> click(button("To-Do Pay your retainer"))
      |> click(button("Pay Invoice"))
      |> assert_url_contains("stripe-checkout")

      assert %{stripe_payment_intent_id: "new_intent_id", stripe_session_id: "new_session_id"} =
               deposit_payment |> Repo.reload()
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
    |> click(@send_proposal_button)
    |> wait_for_enabled_submit_button()
    |> click(@send_email_button)

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("button") |> Map.get(:url)

    client_session
    |> visit(url)
    |> assert_disabled(@invoice_button)
    |> click(button("To-Do Review your proposal"))
    |> click(button("Accept Quote"))
    |> assert_disabled(@invoice_button)
    |> click(button("To-Do Read and agree to your contract"))
    |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
    |> wait_for_enabled_submit_button()
    |> click(button("Accept Contract"))
    |> assert_enabled(@invoice_button)
    |> click(button("To-Do Fill out the initial questionnaire"))
    |> click(checkbox("My partner", selected: false))
    |> click(button("Close"))
    |> click(button("To-Do Fill out the initial questionnaire"))
    |> visit(url)
    |> click(button("To-Do Fill out the initial questionnaire"))
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
    |> click(button("Completed Fill out the initial questionnaire"))
    |> assert_has(checkbox("My partner", selected: true))
  end

  @sessions 2
  feature "client sees custom contract", %{
    user: user,
    sessions: [photographer_session, client_session],
    lead: lead
  } do
    insert(:contract_template,
      user: user,
      job_type: "newborn",
      content: "My custom contract",
      name: "Contract 1"
    )

    photographer_session
    |> visit("/leads/#{lead.id}")
    |> click(checkbox("Questionnaire included", selected: true))
    |> click(button("Edit or Select New"))
    |> find(select("Select a Contract Template"), &click(&1, option("Contract 1")))
    |> fill_in(text_field("Contract Name"), with: "Contract 2")
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> click(@send_proposal_button)
    |> wait_for_enabled_submit_button()
    |> click(@send_email_button)

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("button") |> Map.get(:url)

    client_session
    |> visit(url)
    |> click(button("To-Do Read and agree to your contract"))
    |> assert_text("My custom contract")
  end

  @sessions 2
  feature "client accesses proposal for archived lead", %{
    sessions: [photographer_session, client_session],
    lead: lead
  } do
    insert(:questionnaire)

    photographer_session
    |> visit("/leads/#{lead.id}")
    |> click(@send_proposal_button)
    |> wait_for_enabled_submit_button()
    |> click(@send_email_button)

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("button") |> Map.get(:url)

    lead |> Job.archive_changeset() |> Repo.update!()

    client_session
    |> visit(url)
    |> assert_flash(:error, text: "not available")
  end

  @sessions 2
  feature "proposal is free", %{
    sessions: [photographer_session, client_session],
    lead: lead
  } do
    Repo.update_all(Package, set: [base_multiplier: 0])
    Repo.update_all(PaymentSchedule, set: [price: 0])

    photographer_session
    |> visit("/leads/#{lead.id}")
    |> click(checkbox("Questionnaire included", selected: true))
    |> assert_text("100% discount")
    |> click(@send_proposal_button)
    |> wait_for_enabled_submit_button()
    |> click(@send_email_button)

    assert_receive {:delivered_email, email}
    url = email |> email_substitutions |> Map.get("button") |> Map.get(:url)

    client_session
    |> visit(url)
    |> assert_has(css("h2", text: "Welcome."))
    |> click(button("To-Do Review your proposal"))
    |> click(button("Accept Quote"))
    |> click(button("To-Do Read and agree to your contract"))
    |> assert_text("Retainer and Payment")
    |> fill_in(text_field("Type your full legal name"), with: "Rick Sanchez")
    |> wait_for_enabled_submit_button()
    |> click(button("Accept Contract"))
    |> click(button("Pay your invoice"))
    |> assert_has(definition("Session fee", text: "$1.00"))
    |> assert_has(definition("Discount", text: "100%"))
    |> assert_has(definition("Total", text: "$0.00"))
    |> within_modal(&click(&1, button("Finish booking")))
    |> assert_has(css("h1", text: "Thank you"))
    |> assert_has(css("h1", text: "Your session is now booked."))
    |> click(button("Got it"))
    |> assert_has(button("Completed Pay your invoice"))

    assert_receive {:delivered_email, email}
    %{"subject" => subject, "body" => body} = email |> email_substitutions
    assert "John just completed their booking proposal!" = subject
    assert body =~ "John completed their proposal."
  end
end
