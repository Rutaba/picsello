defmodule Picsello.WelcomePageTest do
  use Picsello.FeatureCase, async: true

  describe "signed in cards" do
    setup do
      [user: insert(:user, %{name: "Morty Smith"}) |> onboard!]
    end

    setup :authenticated

    feature "user sees home page", %{session: session} do
      session
      |> assert_has(css("h1", text: ", Morty!"))
      |> assert_has(css("header", text: "MS"))
      |> assert_path("/home")
    end

    feature "user navigates to leads from navbar", %{session: session} do
      session
      |> click(css("#sub-menu", text: "Your work"))
      |> click(css("nav a", text: "Leads"))
      |> assert_path(Routes.job_path(PicselloWeb.Endpoint, :leads))
    end

    feature "user navigates to leads from sidebar", %{session: session} do
      session
      |> click(css("#hamburger-menu"))
      |> assert_has(css("#hamburger-menu nav a[title='Leads']:not(.font-bold)"))
      |> click(css("#hamburger-menu nav a", text: "Leads"))
      |> assert_path(Routes.job_path(PicselloWeb.Endpoint, :leads))
      |> click(css("#hamburger-menu"))
      |> assert_has(css("nav a.font-bold", text: "Lead"))
    end

    feature "user goes to account page from initials menu", %{session: session} do
      session
      |> click(css("div[title='Morty Smith']"))
      |> click(link("Account"))
      |> assert_path(Routes.user_settings_path(PicselloWeb.Endpoint, :edit))
    end

    feature "user logs out from initials menu", %{session: session} do
      session
      |> click(css("div[title='Morty Smith']"))
      |> click(button("Logout"))
      |> assert_path("/")
      |> assert_flash(:info, text: "Logged out successfully")
    end

    feature "user resends confirmation email", %{session: session} do
      session
      |> assert_has(testid("attention-item", text: "Confirm your email"))
      |> assert_has(testid("attention-item", count: 7))
      |> click(button("Resend email"))

      assert_receive {:delivered_email, email}

      session
      |> visit(email |> email_substitutions |> Map.get("url"))
      |> assert_flash(:info, text: "Your email has been confirmed")
      |> assert_has(testid("attention-item", count: 6))
    end

    feature "user sees attention card to create new lead", %{session: session, user: user} do
      session
      |> assert_has(testid("attention-item", count: 7))
      |> find(
        testid("attention-item", text: "Create your first lead"),
        &click(&1, button("Create your first lead"))
      )
      |> assert_has(css("label", text: "Event"))

      insert(:lead, user: user)

      session
      |> visit("/")
      |> assert_has(testid("attention-item", count: 6))
    end

    feature "user open billing portal from invoices card", %{session: session, user: user} do
      order =
        insert(:order,
          gallery:
            insert(:gallery,
              job: insert(:lead, user: user) |> promote_to_job()
            )
        )

      insert(:invoice,
        order: order,
        status: :open,
        stripe_id: "invoice-stripe-id"
      )

      Mox.stub(Picsello.MockPayments, :create_billing_portal_session, fn _ ->
        {:ok,
         %{
           url:
             PicselloWeb.Endpoint.struct_url()
             |> Map.put(:fragment, "stripe-billing-portal")
             |> URI.to_string()
         }}
      end)

      session
      |> visit("/")
      |> find(
        testid("attention-item", text: "Balance(s) Due"),
        &click(&1, button("Open Billing Portal"))
      )
      |> assert_url_contains("stripe-billing-portal")
    end

    feature "user open billing portal from payment card", %{session: session} do
      Mox.stub(Picsello.MockPayments, :create_billing_portal_session, fn _ ->
        {:ok,
         %{
           url:
             PicselloWeb.Endpoint.struct_url()
             |> Map.put(:fragment, "stripe-billing-portal")
             |> URI.to_string()
         }}
      end)

      session
      |> visit("/")
      |> find(
        testid("attention-item", text: "Missing Payment Method"),
        &click(&1, button("Open Billing Portal"))
      )
      |> assert_url_contains("stripe-billing-portal")
    end
  end

  describe "signed in cards with payment method" do
    feature "user has payment method", %{session: session} do
      user = insert(:user, %{name: "Morty Smith", stripe_customer_id: "cus_12345"}) |> onboard!

      Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "cus_12345", _ ->
        {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
      end)

      session
      |> sign_in(user)
      |> visit("/")
      |> assert_has(testid("attention-item", count: 6))
    end
  end

  describe "lead and job cards" do
    setup do
      [user: insert(:user, %{name: "Morty Smith"}) |> onboard!]
    end

    feature "leads card shows numbers", %{session: session, user: user} do
      _archived = insert(:lead, user: user, archived_at: DateTime.utc_now())
      _pending_1 = insert(:lead, user: user)

      _pending_cold =
        for _ <- 1..3, do: insert(:lead, user: user, booking_proposals: [insert(:proposal)])

      _active_1 =
        insert(:lead,
          user: user,
          booking_proposals: [insert(:proposal, accepted_at: DateTime.utc_now())]
        )

      _active_2 =
        insert(:lead,
          user: user,
          booking_proposals: [
            insert(:proposal,
              accepted_at: DateTime.utc_now(),
              signed_at: DateTime.utc_now(),
              signed_legal_name: "XYZ"
            )
          ]
        )

      session
      |> sign_in(user)
      |> click(button("Leads"))
      |> assert_has(testid("job-row", count: 6))
    end

    feature "leads card has empty state", %{session: session, user: user} do
      session
      |> sign_in(user)
      |> assert_has(button("Leads"))
      |> click(button("Actions"))
      |> assert_has(button("Create lead"))

      insert(:lead, user: user, archived_at: DateTime.utc_now())

      session
      |> click(button("Leads"))
      |> assert_has(css("main > div > ul > li", count: 0))
    end

    feature "jobs card shows numbers", %{session: session, user: user} do
      day = 24 * 60 * 60
      # seconds between insertion and assertion. slow on github.
      delta_seconds = 10

      for(
        seconds_from_now <- [
          -1,
          delta_seconds,
          7 * day - delta_seconds,
          7 * day + delta_seconds
        ]
      ) do
        starts_at = DateTime.add(DateTime.utc_now(), seconds_from_now)

        insert(:lead, user: user, package: %{shoot_count: 1}, shoots: [%{starts_at: starts_at}])
        |> promote_to_job()
      end

      session
      |> sign_in(user)
      |> assert_has(button("Jobs"))
      |> assert_has(testid("badge", text: "2"))
      |> assert_text("jobs upcoming this week")
    end

    feature "jobs card empty state", %{session: session, user: user} do
      insert(:lead, user: user)

      session
      |> sign_in(user)
      |> assert_text("Jobs")

      insert(:lead,
        user: user,
        completed_at: DateTime.utc_now(),
        package: %{shoot_count: 1},
        shoots: [%{starts_at: DateTime.add(DateTime.utc_now(), -1)}]
      )
      |> promote_to_job()

      session
      |> visit("/")
      |> assert_text("Get ready for your calendar to start filling up with shoots!")
    end

    feature "calendar card is empty", %{session: session, user: user} do
      session
      |> sign_in(user)
      |> visit("/")
      |> assert_text("Get ready for your calendar to start filling up with shoots!")
      |> click(button("Create booking event"))
      |> assert_text("Add booking event: Details")
      |> visit("/")
      |> click(button("View calendar"))
      |> assert_text("Calendar")
    end

    feature "clients card is empty", %{session: session, user: user} do
      session
      |> sign_in(user)
      |> assert_text("Let's start by adding your clients - whether they are new")
      |> click(button("Add client"))
      |> assert_text("Add Client: General Details")
      |> visit("/")
      |> click(button("View clients"))
      |> assert_text("Clients")
    end

    feature "support card is empty", %{session: session, user: user} do
      session
      |> sign_in(user)
      |> assert_text("Get in touch with our Customer Success")
      |> click(button("View help center"))
    end

    feature "gallery card is empty", %{session: session, user: user} do
      session
      |> sign_in(user)
      |> assert_text("Galleries")
      |> click(button("Create a gallery"))
      |> assert_text("Create a Gallery")
      |> visit("/")
      |> click(button("View galleries"))
      |> assert_text("Your Galleries")
    end

    feature "actions menu", %{session: session, user: user} do
      session
      |> sign_in(user)
      |> click(button("Actions"))
      |> click(button("Create lead"))
      |> assert_text("Create a lead")
      |> click(button("Cancel"))
      |> click(button("Actions"))
      |> click(button("Create client"))
      |> assert_text("Add Client: General Details")
      |> click(button("Cancel"))
      |> click(button("Actions"))
      |> click(button("Create gallery"))
      |> assert_text("Create a Gallery: Get Started")
      |> click(button("cancel"))
      |> click(button("Actions"))
      |> click(button("Import job"))
      |> assert_text("Import Existing Job: Get Started")
      |> click(button("cancel"))
      |> click(button("Actions"))
      |> click(button("Create booking event", count: 2, at: 1))
      |> assert_text("Add booking event: Details")
      |> visit("/")
      |> click(button("Actions"))
      |> click(button("Create package"))
      |> assert_text("Add a Package: Provide Details")
      |> visit("/")
      |> click(button("Actions"))
      |> click(button("Create questionnaire"))
      |> assert_text("Add questionnaire")
      |> click(button("Cancel"))
    end
  end

  describe "inbox on dashboard" do
    setup do
      user = insert(:user, %{name: "Morty Smith"}) |> onboard!
      insert(:lead, user: user, type: "wedding") |> promote_to_job()
      job = insert(:lead, user: user, type: "family") |> promote_to_job()

      [user: user, job: job]
    end

    feature "inbox card is empty", %{session: session, user: user} do
      session
      |> sign_in(user)
      |> visit("/")
      |> assert_text("This is where you will see new messages from your clients.")
      |> click(button("View inbox"))
      |> assert_text("You don’t have any new messages.")
    end

    feature "inbox card has messages", %{session: session, user: user, job: job} do
      token = Picsello.Messages.token(job)

      session
      |> post(
        "/sendgrid/inbound-parse",
        %{
          "text" => "client response",
          "html" => "<p>client response</p>",
          "subject" => "Re: subject",
          "envelope" => Jason.encode!(%{"to" => ["#{token}@test-inbox.picsello.com"]})
        }
        |> URI.encode_query(),
        [{"Content-Type", "application/x-www-form-urlencoded"}]
      )

      session
      |> sign_in(user)
      |> assert_has(testid("thread-card", count: 1))
      |> assert_has(testid("badge", text: "1"))
      |> assert_text("New")
      |> assert_text("Mary Jane")
    end
  end
end
