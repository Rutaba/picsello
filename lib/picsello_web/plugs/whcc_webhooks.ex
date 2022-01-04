defmodule PicselloWeb.Plugs.WhccWebhook do
  @moduledoc "WHCC webhook validation"
  @behaviour Plug

  def init(config), do: config

  def call(%{request_path: "/whcc/webhook"} = conn, _) do
    {:ok, body, _} = Plug.Conn.read_body(conn)
    Plug.Conn.put_private(conn, :raw_body, body |> IO.inspect())
    # signature = conn |> get_req_header("whcc-signature")
    # payload = Jason.encode!(params)
    # WHCC.webhook_validate(payload, signature)
  end

  def call(conn, _), do: conn
end
