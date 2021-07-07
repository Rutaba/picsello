defmodule Picsello.ResetPasswordErrorTest do
  use Picsello.FeatureCase, async: false

  @tag capture_log: true
  feature "server error on send email", %{session: session} do
    user = insert(:user)

    with_env(:picsello, Picsello.Mailer, [adapter: Bamboo.SendGridAdapter], fn ->
      session
      |> navigate_to_forgot_password()
      |> fill_in(text_field("Email"), with: user.email)
      |> wait_for_enabled_submit_button()
      |> click(button("Reset Password"))
      |> assert_has(css(".alert-error", text: "Unexpected error. Please try again."))
    end)
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
