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
    |> fill_in(text_field("Email"), with: user.email)
    |> assert_has(css("button:not(:disabled)[type='submit']"))
    |> click(button("Reset Password"))
    |> assert_has(css(".alert.alert-info", text: "If your email is in our system"))

    assert current_path(session) == "/"

    assert_receive {:delivered_email, email}

    session
    |> visit(email |> substitutions |> Map.get("%url%"))
    |> assert_has(css("h1", text: "Reset password"))
  end

  defp substitutions(%Bamboo.Email{
         private: %{send_grid_template: %{substitutions: substitutions}}
       }),
       do: substitutions
end
