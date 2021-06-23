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
end
