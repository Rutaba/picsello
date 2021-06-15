defmodule Picsello.ResetPasswordTest do
  use ExUnit.Case, async: false
  use Wallaby.Feature
  import Wallaby.Query
  import Picsello.AccountsFixtures

  feature "user receives new reset password token", %{session: session} do
    user = user_fixture()

    session
    |> visit("/")
    |> click(css("a", text: "Log In"))
    |> click(css("a", text: "Forgot Password"))
    |> fill_in(text_field("Email"), with: user.email)
    |> assert_has(css("button:not(:disabled)[type='submit']"))
    |> click(button("Reset Password"))
    |> assert_has(css(".alert.alert-info", text: "If your email is in our system"))

    assert current_path(session) == "/"
  end
end
