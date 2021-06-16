defmodule Picsello.ResetPasswordTest do
  use ExUnit.Case, async: false
  use Wallaby.Feature
  use Bamboo.Test, shared: true
  import Wallaby.Query
  import Picsello.AccountsFixtures

  feature "user receives new reset password token", %{session: session} do
    user = user_fixture()

    session
    |> visit("/")
    |> click(css("a", text: "Log In"))
    |> click(css("a", text: "Forgot Password"))
    |> fill_in(text_field("Email"), with: "invalid")
    |> assert_has(css("label", text: "Email must have the @ sign and no spaces"))
    |> fill_in(text_field("Email"), with: user.email)
    |> assert_has(css("button:not(:disabled)[type='submit']"))
    |> click(button("Reset Password"))
    |> assert_has(css(".alert.alert-info", text: "If your email is in our system"))

    assert current_path(session) == "/"

    assert_receive {:delivered_email, email}

    session
    |> visit(email |> substitutions |> Map.get("%url%"))
    |> assert_has(css("h1", text: "Reset your password"))
    |> fill_in(text_field("New password"), with: " ")
    |> assert_has(css("label", text: "New password can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("New password"), with: "ThisIsAStrongP@ssw0rd")
    |> assert_has(css("button:not(:disabled)[type='submit']"))
    |> click(button("Reset Password"))
    |> assert_has(css(".alert.alert-info", text: "Password reset successfully."))

    assert current_path(session) == "/users/log_in"

    session
    |> fill_in(text_field("Email"), with: user.email)
    |> fill_in(text_field("Password"), with: "ThisIsAStrongP@ssw0rd")
    |> assert_has(css("button:not(:disabled)[type='submit']"))
    |> click(button("Log In"))
    |> assert_has(css("h1", text: "Hello #{user.first_name}"))
  end

  feature "user visits invalid reset password link", %{session: session} do
    session
    |> visit("/users/reset_password/invalid-token")
    |> assert_has(
      css(".alert.alert-error", text: "Reset password link is invalid or it has expired.")
    )

    assert current_path(session) == "/"
  end

  defp substitutions(%Bamboo.Email{
         private: %{send_grid_template: %{substitutions: substitutions}}
       }),
       do: substitutions
end
