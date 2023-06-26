defmodule PicselloWeb.NylasController do
  @moduledoc """
  Elixir code to set the token from nylas. The user will be directed
  via a link in the `live/calendar/index.html.ex` module to Nylas
  which will do its oauth magic. Assuming that everything goes
  correctly the user will be redirected to this page. We will fetch
  the token with the code `NylasCalendar.fetch_token/1` and save it
  with `Picsello.Accounts.set_user_nylas_code/2` and then redirect the
  user back to the calendar.
  """

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
