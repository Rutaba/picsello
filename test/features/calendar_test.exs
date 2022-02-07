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

  feature "displays the shoot in the calendar", %{session: session} do
    session
    |> visit("/calendar")
    |> assert_text("John Wedding - Shoot 1")
    |> assert_text("Mary Wedding - Shoot 2")
    |> assert_has(css(".fc-event", count: 2))
    |> click(button("Previous month"))
    |> assert_has(css(".fc-event", count: 0))
  end
end
