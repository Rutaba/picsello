defmodule Picsello.CalendarSettingsTest do
  @moduledoc false
  use Picsello.FeatureCase, async: false

  setup :onboarded
  setup :authenticated

  feature "Calendar settings header test", %{session: session} do
    session
    |> visit("/calendar/settings")
    |> assert_text("2-way Calendar Sync")
    |> assert_has(css("a[href*='/calendar']", count: 2))
    |> click(css("#copy-calendar-link"))
    |> assert_url_contains("calendar")
  end

  feature "Calendar settings copy url test", %{session: session} do
    session
    |> visit("/calendar/settings")
    |> assert_text("2-way Calendar Sync")
    |> assert_text("1-way Calendar Sync")
    |> click(button("Copy link"))
    |> assert_text("Copied!")
  end
end
