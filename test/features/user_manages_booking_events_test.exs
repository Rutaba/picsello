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
end
