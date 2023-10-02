defmodule Picsello.UserOnboardsIntroTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup do
    user = insert(:user)

    [user: user]
  end

  setup :onboarded_show_intro
  setup :authenticated

  feature "user gets welcome modal", %{session: session} do
    session
    |> assert_text("Welcome to Picsello!")
    |> assert_text("Let's do it")
    |> assert_text("Not yet, I want to play around first")
  end

  feature "user gets welcome modal, clicks I want to play", %{session: session} do
    session
    |> assert_text("Welcome to Picsello!")
    |> click(button("Not yet, I want to play around first"))
    |> refute_has(css("#welcome-text", text: "Welcome to Picsello!"))
  end
end
