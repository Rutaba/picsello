defmodule PicselloWeb.NylasController do
  use PicselloWeb, :controller
  require Logger

  @spec callback(Plug.Conn.t(), any) :: Plug.Conn.t()
  def callback(%Plug.Conn{assigns: %{current_user: _user}} = conn, %{"code" => _code}) do
    text(conn, "OK")
  end
end
