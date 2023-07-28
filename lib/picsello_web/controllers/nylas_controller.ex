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
  alias Picsello.{NylasCalendar, NylasDetail}
  require Logger

  @spec callback(Plug.Conn.t(), any) :: Plug.Conn.t()
  def callback(%Plug.Conn{assigns: %{current_user: %{nylas_detail: nylas_detail}}} = conn, %{
        "code" => code
      }) do
    case NylasCalendar.fetch_token(code) do
      {:ok, token} ->
        {:ok, [%{"account_id" => account_id} | _]} = NylasCalendar.get_calendars(token)

        NylasDetail.set_nylas_token!(nylas_detail, %{
          oauth_token: token,
          account_id: account_id,
          event_status: event_status(nylas_detail.account_id, account_id)
        })

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

  defp event_status(nil, _account_id), do: :moved
  defp event_status(account_id, account_id), do: :moved
  defp event_status(_, _), do: :in_progress
end
