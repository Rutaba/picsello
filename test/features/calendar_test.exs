defmodule Picsello.CalendarTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    # dates before the first suday or after the last saturday will be shown on adjacent months
    a_time_only_shown_this_month = DateTime.utc_now() |> Map.put(:day, 15)

    job =
      insert(:lead, %{
        user: user,
        package: %{
          shoot_count: 1
        },
        client: %{name: "John"}
      })

    insert(:shoot,
      name: "Shoot 1",
      job: job,
      starts_at: a_time_only_shown_this_month
    )

    job |> promote_to_job()

    lead =
      insert(:lead, %{
        user: user,
        package: %{
          shoot_count: 1
        },
        client: %{name: "Mary"}
      })

    insert(:shoot,
      name: "Shoot 2",
      job: lead,
      starts_at: a_time_only_shown_this_month
    )

    old_lead =
      insert(:lead, %{
        user: user,
        package: %{
          shoot_count: 1
        },
        client: %{name: "Jack"}
      })

    insert(:shoot,
      name: "Shoot 3",
      job: old_lead,
      starts_at: DateTime.utc_now() |> DateTime.add(100 * 24 * 60 * 60)
    )

    [session: session]
  end

  feature "Calendar header test", %{session: session} do
    session
    |> visit("/calendar")
    |> assert_text("Calendar")
    |> assert_has(css("a[href*='/home']", count: 3))
    |> assert_has(css("a[href*='/calendar/settings']", text: "Settings"))
    |> click(css("a[href*='/calendar/settings']", text: "Settings"))
    |> assert_url_contains("settings")
  end

  feature "displays the shoot in the calendar", %{session: session} do
    session
    |> visit("/calendar")
    |> assert_text("John Wedding - Shoot 1")
    |> assert_text("Mary Wedding - Shoot 2")
    |> assert_has(css(".fc-event", count: 2))
    |> click(button("Previous month"))
    |> assert_has(css(".fc-event", count: 0))
  end

  feature "does not display booking leads", %{session: session, user: user} do
    template = insert(:package_template, user: user)
    event = insert(:booking_event, package_template_id: template.id)

    archived_booking_lead =
      insert(:lead, user: user, archived_at: DateTime.utc_now(), booking_event_id: event.id)

    insert(:shoot, job: archived_booking_lead, starts_at: DateTime.utc_now())

    booking_lead = insert(:lead, user: user, booking_event_id: event.id)
    insert(:shoot, job: booking_lead, starts_at: DateTime.utc_now())

    session
    |> visit("/calendar")
    |> assert_has(css(".fc-event", count: 2))
  end
end
