defmodule Picsello.WelcomePageTest do
  use Picsello.FeatureCase, async: true
  import Picsello.AccountsFixtures

  feature "user logs in", %{session: session} do
    user = user_fixture(%{first_name: "Morty", last_name: "Smith"})

    session
    |> sign_in(user)
    |> assert_has(css("h1", text: "Hello Morty"))
    |> assert_has(css("header", text: "MS"))

    assert current_path(session) == "/home"
  end
end
