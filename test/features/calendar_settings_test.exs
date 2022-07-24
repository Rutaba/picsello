defmodule Picsello.CalendarSettingsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  feature "Calendar settings header test", %{session: session} do
    session
    |> visit("/calendar/settings")
    |> assert_text("Calendar Settings")
    |> assert_has(css("a[href*='/calendar']", count: 2))
    |> click(link("Calendar"))
    |> assert_url_contains("calendar")
  end

  feature "Calendar settings copy url test", %{session: session} do
    session
    |> visit("/calendar/settings")
    |> assert_text("Subscribe to your Picsello calendar")
    |> assert_text("Copy this link if you need to subscribe")
    |> click(button("Copy link"))
    |> assert_text("Copied!")
    |> click(link("Calendar"))
    |> assert_url_contains("calendar")
  end
end
