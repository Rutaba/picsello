defmodule Picsello.WelcomePageTest do
  use Picsello.FeatureCase, async: true

  setup do
    [user: insert(:user, %{name: "Morty Smith"}) |> onboard!]
  end

  describe "signed in" do
    setup :authenticated

    feature "user sees home page", %{session: session} do
      session
      |> assert_has(css("h1", text: ", Morty!"))
      |> assert_has(css("header", text: "MS"))
      |> assert_path("/home")
    end

    feature "user navigates to leads from navbar", %{session: session} do
      session
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
      |> assert_has(testid("attention-item", count: 4))
      |> click(button("Resend email"))

      assert_receive {:delivered_email, email}

      session
      |> visit(email |> email_substitutions |> Map.get("url"))
      |> assert_flash(:info, text: "Your email has been confirmed")
      |> assert_has(testid("attention-item", count: 3))
    end

    feature "user sees attention card to create new lead", %{session: session, user: user} do
      session
      |> assert_has(testid("attention-item", count: 4))
      |> find(
        testid("attention-item", text: "Create your first lead"),
        &click(&1, button("Create your first lead"))
      )
      |> assert_has(text_field("Client Name"))

      insert(:lead, user: user)

      session
      |> visit("/")
      |> assert_has(testid("attention-item", count: 3))
    end

    feature "user opens lead creation from floating menu", %{session: session} do
      session
      |> assert_has(css("#float-menu", visible: false))
      # iPhone 8+
      |> resize_window(414, 736)
      |> assert_has(css("#float-menu", visible: true))
      |> click(css("#float-menu svg"))
      |> click(link("Add a lead"))
      |> assert_has(text_field("Client Name"))
    end
  end

  def lead_counts(session) do
    card =
      session
      |> find(testid("leads-card"))

    badge = card |> find(testid("badge")) |> Element.text()

    counts =
      card
      |> find(css("li", count: 2))
      |> Enum.map(&Element.text/1)

    {badge, counts |> hd, counts |> tl |> hd}
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

    counts =
      session
      |> sign_in(user)
      |> lead_counts()

    assert {"6", "4 pending leads", "2 active leads"} == counts
  end

  feature "leads card has empty state", %{session: session, user: user} do
    session
    |> sign_in(user)
    |> find(testid("leads-card"))
    |> assert_text("Create leads to start")

    insert(:lead, user: user, archived_at: DateTime.utc_now())

    counts = session |> visit("/") |> lead_counts()

    assert {"", "0 pending leads", "0 active leads"} == counts
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
    |> find(testid("jobs-card"))
    |> assert_has(testid("badge", text: "2"))
    |> assert_text("2 upcoming jobs within the next seven days")
  end

  feature "jobs card empty state", %{session: session, user: user} do
    insert(:lead, user: user)

    session |> sign_in(user) |> find(testid("jobs-card")) |> assert_text("Leads will become jobs")

    insert(:lead,
      user: user,
      completed_at: DateTime.utc_now(),
      package: %{shoot_count: 1},
      shoots: [%{starts_at: DateTime.add(DateTime.utc_now(), -1)}]
    )
    |> promote_to_job()

    session |> visit("/") |> find(testid("jobs-card")) |> assert_text("0 upcoming jobs")
  end
end
