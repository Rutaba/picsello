defmodule Picsello.UserManagesBookingEventsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  feature "sees empty state", %{session: session} do
    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> assert_text("You don’t have any booking events created at the moment")
  end

  feature "creates new booking event", %{session: session, user: user} do
    insert(:package_template, user: user, job_type: "wedding")
    insert(:package_template, user: user, job_type: "mini", name: "Mini 1")
    insert(:package_template, user: user, job_type: "mini", name: "Mini 2")

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> click(link("Add booking event"))
    |> assert_text("Add booking event: Details")
    |> fill_in(text_field("Title"), with: "My event")
    |> find(select("Shoot Location"), &click(&1, option("On Location")))
    |> fill_in(text_field("Shoot Address"), with: "320 1st St N, Jax Beach, FL")
    |> find(select("Session Length"), &click(&1, option("45 mins")))
    |> find(select("Session Buffer"), &click(&1, option("15 mins")))
    |> fill_in(text_field("booking_event[dates][0][date]"), with: "10/10/2050")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][0][start_time]"), with: "09:00AM")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][0][end_time]"), with: "01:00PM")
    |> scroll_into_view(testid("add-date"))
    |> click(button("Add block"))
    |> fill_in(text_field("booking_event[dates][0][time_blocks][1][start_time]"), with: "03:00PM")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][1][end_time]"), with: "05:00PM")
    |> click(button("Add another date"))
    |> assert_has(testid("event-date", count: 2))
    |> scroll_into_view(testid("add-date"))
    |> fill_in(text_field("booking_event[dates][1][date]"), with: "10/11/2050")
    |> fill_in(text_field("booking_event[dates][1][time_blocks][0][start_time]"), with: "09:00AM")
    |> fill_in(text_field("booking_event[dates][1][time_blocks][0][end_time]"), with: "10:00AM")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add booking event: Select package")
    |> assert_disabled_submit(text: "Next")
    |> assert_has(testid("template-card", count: 2))
    |> click(testid("template-card", text: "Mini 1"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add booking event: Customize")
  end
end
