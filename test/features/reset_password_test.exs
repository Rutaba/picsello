defmodule Picsello.ResetPasswordTest do
  use Picsello.FeatureCase
  use Bamboo.Test, shared: true
  import Picsello.AccountsFixtures

  feature "user resets password", %{session: session} do
    user = user_fixture()

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
    |> visit(email |> substitutions |> Map.get("%url%"))
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

  feature "user visits invalid reset password link", %{session: session} do
    session
    |> visit("/users/reset_password/invalid-token")
    |> assert_has(
      css(".alert.alert-error", text: "Reset password link is invalid or it has expired.")
    )

    assert current_path(session) == "/users/reset_password"
  end

  @tag capture_log: true
  feature "server error on send email", %{session: session} do
    user = user_fixture()

    with_env(:picsello, Picsello.Mailer, [adapter: Bamboo.SendGridAdapter], fn ->
      session
      |> navigate_to_forgot_password()
      |> fill_in(text_field("Email"), with: user.email)
      |> wait_for_enabled_submit_button()
      |> click(button("Reset Password"))
      |> assert_has(css(".alert-error", text: "Unexpected error. Please try again."))
    end)
  end

  defp substitutions(%Bamboo.Email{
         private: %{send_grid_template: %{substitutions: substitutions}}
       }),
       do: substitutions

  defp navigate_to_forgot_password(session) do
    session
    |> visit("/")
    |> click(css("a", text: "Log In"))
    |> click(css("a", text: "Forgot Password"))
  end

  defp with_env(app, key, value, fun) do
    original = Application.get_env(app, key)

    try do
      Application.put_env(app, key, value)
      fun.()
    after
      Application.put_env(app, key, original)
    end
  end
end
