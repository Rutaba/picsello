defmodule PicselloWeb.Plugs.Telemetry do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts), do: Plug.Telemetry.init(opts)

  @impl true
  def call(%Plug.Conn{request_path: "/health_check"} = conn, {start_event, stop_event, opts}) do
    Plug.Telemetry.call(conn, {start_event, stop_event, Keyword.put(opts, :log, :debug)})
  end

  def call(conn, args), do: Plug.Telemetry.call(conn, args)
end
