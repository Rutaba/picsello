defmodule Picsello.ResetPasswordTest do
  use Picsello.FeatureCase, async: true

  feature "user visits invalid reset password link", %{session: session} do
    session
    |> visit("/users/reset_password/invalid-token")
    |> assert_has(
      css(".alert.alert-error", text: "Reset password link is invalid or it has expired.")
    )
    |> assert_path("/users/reset_password")
  end

  feature "user resets password", %{session: session} do
    user = insert(:user)

    session
    |> navigate_to_forgot_password()
    |> fill_in(text_field("Email"), with: "invalid")
    |> assert_has(css("label", text: "Email must have the @ sign and no spaces"))
    |> fill_in(text_field("Email"), with: user.email)
    |> wait_for_enabled_submit_button()
    |> click(button("Reset Password"))
    |> assert_has(css(".alert.alert-info", text: "If your email is in our system"))

    assert current_path(session) == "/"

    assert_receive {:delivered_email, email}

    session
    |> visit(email |> email_substitutions |> Map.get("url"))
    |> assert_has(css("h1", text: "Reset your password"))
    |> fill_in(text_field("New password"), with: " ")
    |> assert_has(css("label", text: "New password can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("New password"), with: "ThisIsAStrongP@ssw0rd")
    |> wait_for_enabled_submit_button()
    |> click(button("Reset Password"))
    |> assert_has(css(".alert.alert-info", text: "Password reset successfully."))

    assert current_path(session) == "/users/log_in"

    session
    |> sign_in(user, "ThisIsAStrongP@ssw0rd")
    |> assert_has(css("h1", text: "Hello #{user.first_name}"))
  end
end
