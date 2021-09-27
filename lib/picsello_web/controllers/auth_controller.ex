defmodule PicselloWeb.AuthController do
  use PicselloWeb, :controller
  plug Ueberauth
  require Logger

  alias PicselloWeb.UserAuth

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}, req_cookies: cookies} = conn, _params) do
    case Picsello.Accounts.user_from_auth(auth, cookies |> Map.get("time_zone")) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        Logger.info(fn ->
          "auth failed: " <> inspect(Ecto.Changeset.traverse_errors(changeset, & &1))
        end)

        conn
        |> put_flash(:error, "We're having trouble on our end. Please contact support.")
        |> redirect(to: "/")
    end
  end
end
