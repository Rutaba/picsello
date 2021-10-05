defmodule Picsello.WelcomePageTest do
  use Picsello.FeatureCase, async: true

  feature "user sees home page", %{session: session} do
    user = insert(:user, %{name: "Morty Smith"}) |> onboard!

    session
    |> sign_in(user)
    |> assert_has(css("h1", text: ", Morty!"))
    |> assert_has(css("header", text: "MS"))
    |> assert_path("/home")
  end
end
