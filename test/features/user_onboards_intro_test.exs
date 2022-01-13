defmodule Picsello.UserOnboardsIntroTest do
  use Picsello.FeatureCase, async: true

  setup do
    user = insert(:user)

    [user: user]
  end

  setup :onboarded_show_intro
  setup :authenticated

  feature "user has intro js loaded", %{session: session} do
    session
    |> find(Query.data("intro-show", "true"))
  end

  feature "user interacts with intro js tour and completes it", %{session: session} do
    session
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-nextbutton"))
    |> click(css(".introjs-donebutton"))
    |> visit("/")
    |> find(Query.data("intro-show", "false"))
  end

  feature "user interacts with intro js tour and dismisses it", %{session: session} do
    session
    |> click(css(".introjs-skipbutton"))
    |> visit("/")
    |> find(Query.data("intro-show", "false"))
  end
end
