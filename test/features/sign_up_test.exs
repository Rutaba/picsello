defmodule Picsello.SignUpTest do
  use Picsello.FeatureCase

  feature "user views sign up button", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("a", text: "Sign Up"))
  end

  feature "user signs up", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> fill_in(text_field("First name"), with: "Mary")
    |> fill_in(text_field("Last name"), with: "Jane")
    |> fill_in(text_field("Photography business name"), with: "Jane")
    |> fill_in(text_field("Email"), with: "user@example.com")
    |> fill_in(text_field("Password"), with: "ThisIsAStrongP@ssw0rd")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Hello Mary!"))

    assert current_path(session) == "/home"
  end

  feature "user sees validation error when signing up", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> fill_in(text_field("First name"), with: "Mary")
    |> fill_in(text_field("Last name"), with: "Jane")
    |> fill_in(text_field("Photography business name"), with: "Jane")
    |> fill_in(text_field("Email"), with: "user@example.com")
    |> fill_in(text_field("Password"), with: "123")
    |> assert_has(css("label", text: "Password should be at least 12 character(s)"))
    |> assert_has(css("button:disabled[type='submit']", text: "Save"))

    assert current_path(session) == "/users/register"
  end

  feature "user toggles password visibility", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> fill_in(text_field("Password"), with: "123")
    |> assert_has(css("#user_password[type='password']"))
    |> click(css("a", text: "show"))
    |> assert_has(css("#user_password[type='text']"))
    |> click(css("a", text: "hide"))
    |> assert_has(css("#user_password[type='password']"))
  end
end
