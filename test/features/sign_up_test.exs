defmodule Picsello.SignInTest do
  use ExUnit.Case, async: true
  use Wallaby.Feature
  import Wallaby.Query

  feature "user views sign up button", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("a", text: "Sign Up"))
  end

  feature "user signs up", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> fill_in(text_field("First Name"), with: "Mary")
    |> fill_in(text_field("Last Name"), with: "Jane")
    |> fill_in(text_field("Photography Business Name"), with: "Jane")
    |> fill_in(text_field("Email"), with: "user@example.com")
    |> fill_in(text_field("Password"), with: "ThisIsAStrongP@ssw0rd")
    |> click(button("Save"))

    assert current_path(session) == "/"
  end

  feature "user sees validation error when signing up", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> fill_in(text_field("First Name"), with: "Mary")
    |> fill_in(text_field("Last Name"), with: "Jane")
    |> fill_in(text_field("Photography Business Name"), with: "Jane")
    |> fill_in(text_field("Email"), with: "user@example.com")
    |> fill_in(text_field("Password"), with: "123")
    |> click(button("Save"))
    |> assert_has(css("label", text: "Password should be at least 12 character(s)"))

    assert current_path(session) == "/users/register"
  end
end
