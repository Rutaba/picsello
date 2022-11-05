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
    |> visit("/home?new_user=true")
    |> assert_text("Welcome to the Picsello Family!")
    |> click(css(".welcome-column", count: 3, at: 0))
    |> assert_path("/booking-events")
    |> assert_text("Booking events")
    |> visit("/home?new_user=true")
    |> assert_text("Start product tour")
  end

  feature "user gets welcome modal, clicks galleries", %{session: session} do
    session
    |> visit("/home?new_user=true")
    |> assert_text("Welcome to the Picsello Family!")
    |> click(css(".welcome-column", count: 3, at: 1))
    |> assert_path("/galleries")
    |> assert_text("Your Galleries")
    |> visit("/home?new_user=true")
    |> assert_text("Start product tour")
  end

  feature "user gets welcome modal, clicks demo", %{session: session} do
    session
    |> visit("/home?new_user=true")
    |> assert_text("Welcome to the Picsello Family!")
    |> click(link("Join a demo"))
    |> visit("/home?new_user=true")
    |> assert_text("Welcome to the Picsello Family!")
  end

  feature "user has intro js loaded", %{session: session} do
    session
    |> find(Query.data("intro-show", "true"))
  end

  feature "users starts product tour and uses it", %{session: session} do
    session
    |> click(css("#start-tour"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-donebutton"))
    |> visit("/home")
    |> refute_has(css("#start-tour"))
  end

  feature "user interacts with intro js tour and dismisses it", %{session: session} do
    session
    |> click(css("#start-tour"))
    |> click(css(".introjs-skipbutton"))
    |> visit("/")
    |> find(Query.data("intro-show", "false"))
  end
end
