defmodule PicselloWeb.NylasController do
  use PicselloWeb, :controller
  alias Picsello.Accounts
  require Logger

  @spec callback(Plug.Conn.t(), any) :: Plug.Conn.t()
  def callback(%Plug.Conn{assigns: %{current_user: user}} = conn, %{"code" => code}) do
    Accounts.set_user_nylas_code(user, code)

    conn
    |> put_status(302)
    |> redirect(to: "/calendar")
    |> Plug.Conn.halt()
  end
end
