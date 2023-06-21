defmodule PicselloWeb.NylasController do
  use PicselloWeb, :controller
  alias Picsello.Accounts
  require Logger

  @spec callback(Plug.Conn.t(), any) :: Plug.Conn.t()
  def callback(%Plug.Conn{assigns: %{current_user: user}} = conn, %{"code" => code}) do
    case NylasCalendar.fetch_token(code) do
      {:ok, token} ->
        Accounts.set_user_nylas_code(user, token)

        conn
        |> put_status(302)
        |> redirect(to: "/calendar")
        |> Plug.Conn.halt()

      {:error, e} ->
        Logger.info("Token Error #{e}")

        conn
        |> put_status(404)
        |> Plug.Conn.halt()
    end
  end
end
