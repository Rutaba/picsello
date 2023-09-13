defmodule Picsello.CalendarSettingsTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  feature "Calendar settings header test", %{session: session} do
    session
    |> visit("/calendar/settings")
    |> assert_text("Calendar Settings")
    |> assert_has(css("a[href*='/calendar']", count: 3))
    |> click(link("Calendar", count: 2, at: 1))
    |> assert_url_contains("calendar")
  end

  feature "Calendar settings copy url test", %{session: session} do
    session
    |> visit("/calendar/settings")
    |> assert_text("Subscribe to your Picsello calendar")
    |> assert_text("Copy this link if you need to subscribe")
    |> click(button("Copy link"))
    |> assert_text("Copied!")
  end
end
