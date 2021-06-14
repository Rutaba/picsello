defmodule Picsello.SignInTest do
  use ExUnit.Case, async: false
  use Wallaby.Feature
  import Wallaby.Query
  import Picsello.AccountsFixtures

  feature "user views log in button", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("a", text: "Log In"))
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> assert_has(css("a", text: "Log In"))
  end

  feature "user tries to log in", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Log In"))
    |> fill_in(text_field("Email"), with: "user@example.com")
    |> fill_in(text_field("Password"), with: "ThisIsAStrongP@ssw0rd")
    |> assert_has(css("button:not(:disabled)[type='submit']", text: "Log In"))
    |> click(button("Log In"))
    |> assert_has(css("p.text-red-invalid", text: "Invalid email or password"))
  end

  feature "user logs in", %{session: session} do
    user = user_fixture()

    session
    |> visit("/")
    |> click(css("a", text: "Log In"))
    |> fill_in(text_field("Email"), with: user.email)
    |> fill_in(text_field("Password"), with: valid_user_password())
    |> assert_has(css("button:not(:disabled)[type='submit']", text: "Log In"))
    |> click(button("Log In"))
    |> assert_has(css("h1", text: "Hello #{user.first_name}"))

    assert current_path(session) == "/home"
  end
end
