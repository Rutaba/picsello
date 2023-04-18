defmodule PicselloWeb.UserSettingsControllerTest do
  use PicselloWeb.ConnCase, async: true

  alias Picsello.Accounts

  setup :register_and_log_in_user

  setup do
    Picsello.MockPayments
    |> Mox.stub(:create_account, fn %{type: "standard"}, _ ->
      {:ok, %Stripe.Account{id: "foo"}}
    end)
    |> Mox.stub(:create_account_link, fn %{type: "account_onboarding", account: "foo"}, _ ->
      {:ok, %Stripe.AccountLink{url: "https://stripe.com"}}
    end)

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok
  end

  describe "PUT /users/settings (change password form)" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_password",
          "user" => %{
            "password" => "new valid password",
            "password_to_change" => valid_user_password()
          }
        })

      assert redirected_to(new_password_conn) == Routes.user_settings_path(conn, :edit)
      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)
      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~ "Password updated successfully"
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_password",
          "user" => %{
            "password_to_change" => "invalid",
            "password" => "too short"
          }
        })

      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Could not change password"
      assert get_session(conn, :user_token) == get_session(conn, :user_token)
    end
  end

  describe "GET /users/settings/confirm_email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Email changed successfully"
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"

      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end
  end

  describe "GET /users/settings/stripe-refresh" do
    test "sends us over to stripe", %{conn: conn} do
      conn = conn |> get(conn |> Routes.user_settings_path(:stripe_refresh))

      host = conn |> redirected_to |> URI.parse() |> Map.get(:host)

      assert String.contains?(host, "stripe")
    end
  end
end
