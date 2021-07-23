defmodule Picsello.ResetPasswordErrorTest do
  use Picsello.FeatureCase, async: true

  @tag capture_log: true
  feature "server error on send email", %{session: session} do
    user = insert(:user)

    Mox.stub(Picsello.MockBambooAdapter, :deliver, fn _email, _config -> raise "something bad" end)

    session
    |> navigate_to_forgot_password()
    |> fill_in(text_field("Email"), with: user.email)
    |> wait_for_enabled_submit_button()
    |> click(button("Reset Password"))
    |> assert_has(css(".alert-error", text: "Unexpected error. Please try again."))
  end
end
