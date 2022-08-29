defmodule Picsello.SignInTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Accounts.User

  setup do
    insert_subscription_plans!()

    :ok
  end

  feature "user views log in button", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("a", text: "Log In"))
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> assert_has(css("a", text: "log in"))
  end

  feature "user tries to log in", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Log In"))
    |> fill_in(text_field("Email"), with: "user@example.com")
    |> fill_in(text_field("Password"), with: "ThisIsAStrongP@ssw0rd")
    |> wait_for_enabled_submit_button()
    |> click(button("Login"))
    |> assert_has(css("p.text-red-sales-300", text: "Invalid email or password"))
  end

  feature "new user logs in", %{session: session} do
    user = insert(:user)

    session
    |> visit("/")
    |> click(css("a", text: "Log In"))
    |> fill_in(text_field("Email"), with: user.email)
    |> fill_in(text_field("Password"), with: valid_user_password())
    |> wait_for_enabled_submit_button()
    |> click(button("Login"))
    |> assert_path("/onboarding")
  end

  feature "onboarded user logs in", %{session: session} do
    user = insert(:user) |> onboard!()

    session
    |> visit("/")
    |> click(css("a", text: "Log In"))
    |> fill_in(text_field("Email"), with: user.email)
    |> fill_in(text_field("Password"), with: valid_user_password())
    |> wait_for_enabled_submit_button()
    |> click(button("Login"))
    |> assert_has(css("h1", text: ", #{User.first_name(user)}!"))
    |> assert_path("/home")
  end
end
