defmodule PicselloWeb.Plugs.WhccWebhook do
  @moduledoc "WHCC webhook validation"
  @behaviour Plug

  import Plug.Conn
  require Logger

  def init(config), do: config

  def call(%{request_path: "/whcc/webhook"} = conn, _) do
    {:ok, body, conn} = read_body(conn)

    conn
    |> handle_request(body)
  end

  def call(conn, _), do: conn

  def handle_request(conn, "verifier=" <> hash) do
    conn
    |> struct(%{body_params: %{"verifier" => hash}})
  end

  def handle_request(conn, body) do
    with [signature] <- get_req_header(conn, "whcc-signature"),
         %{"isValid" => true} <- Picsello.WHCC.webhook_validate(body, signature) do
      conn
      |> struct(%{body_params: Jason.decode!(body)})
    else
      _ ->
        Logger.error("[whcc] Error verifying #{body}")

        conn
        |> send_resp(400, "")
        |> halt
    end
  end
end
