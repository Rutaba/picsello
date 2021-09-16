defmodule Picsello.WelcomePageTest do
  use Picsello.FeatureCase, async: true

  feature "user logs in", %{session: session} do
    user = insert(:user, %{name: "Morty Smith"})

    session
    |> sign_in(user)
    |> assert_has(css("h1", text: "Hello Morty"))
    |> assert_has(css("header", text: "MS"))
    |> assert_path("/home")
  end
end
