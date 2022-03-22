defmodule PicselloWeb.UserSettingsController do
  use PicselloWeb, :controller

  alias Picsello.{Accounts, Payments}
  alias PicselloWeb.UserAuth

  def update(conn, %{"action" => "update_password"} = params) do
    %{"user" => %{"password_to_change" => password} = user_params} = params
    user = conn.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, Routes.user_settings_path(conn, :edit))
        |> UserAuth.log_in_user(user)

      {:error, _} ->
        conn
        |> put_flash(:error, "Could not change password. Please try again.")
        |> redirect(to: Routes.user_settings_path(conn, :edit))
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: Routes.user_settings_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: Routes.user_settings_path(conn, :edit))
    end
  end

  def stripe_refresh(%{assigns: %{current_user: current_user}} = conn, %{}) do
    refresh_url = conn |> Routes.user_settings_url(:stripe_refresh)
    return_url = conn |> Routes.home_url(:index)

    case Payments.link(current_user, refresh_url: refresh_url, return_url: return_url) do
      {:ok, url} -> conn |> redirect(external: url)
      _ -> conn |> put_flash(:error, "Something went wrong. So sad.") |> redirect(to: return_url)
    end
  end
end
