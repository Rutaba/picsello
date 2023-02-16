defmodule Picsello.UserOnboardsIntroTest do
  use Picsello.FeatureCase, async: true

  setup do
    user = insert(:user)

    [user: user]
  end

  setup :onboarded_show_intro
  setup :authenticated

  feature "user gets welcome modal, clicks client booking", %{session: session} do
    session
    |> assert_text("Welcome to the Picsello Family!")
    |> click(css(".welcome-column", count: 3, at: 0))
    |> assert_path("/booking-events")
    |> assert_text("Booking events")
    |> visit("/home")
    |> assert_text("To do")
  end

  feature "user gets welcome modal, clicks galleries", %{session: session} do
    session
    |> assert_text("Welcome to the Picsello Family!")
    |> click(css(".welcome-column", count: 3, at: 1))
    |> assert_path("/galleries")
    |> assert_text("Your Galleries")
    |> visit("/home")
    |> assert_text("To do")
  end

  feature "user gets welcome modal, clicks demo", %{session: session} do
    session
    |> assert_text("Welcome to the Picsello Family!")
    |> click(link("Join a demo"))
    |> visit("/home")
    |> refute_has(css("#welcome-text", text: "Welcome to the Picsello Family!"))
  end
end
