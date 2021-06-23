defmodule Picsello.SignInTest do
  use Picsello.FeatureCase, async: true
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
    |> wait_for_enabled_submit_button()
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
    |> wait_for_enabled_submit_button()
    |> click(button("Log In"))
    |> assert_has(css("h1", text: "Hello #{user.first_name}"))
    |> assert_path("/home")
  end
end
