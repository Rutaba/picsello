defmodule PicselloWeb.WhccWebhookController do
  use PicselloWeb, :controller
  require Logger
  alias Picsello.WHCC

  def webhook(%Plug.Conn{} = conn, %{"verifier" => hash}) do
    %{"isVerified" => true} = WHCC.webhook_verify(hash)
    Logger.info("[whcc] Webhook regestered successfully")
    conn |> ok()
  end

  def webhook(
        %Plug.Conn{} = conn,
        %{
          "Status" => "Accepted"
        } = params
      ) do
    # signature = conn |> get_req_header("whcc-signature")
    # payload = Jason.encode!(params)

    # WHCC.webhook_validate(payload, signature)

    Picsello.Cart.store_car_product_processing(params)

    conn.private.raw_body |> IO.inspect(label: "raw body")

    conn |> ok()
  end

  def webhook(%Plug.Conn{} = conn, params) do
    IO.inspect(conn, label: "conn")
    IO.inspect(params, label: "params")

    conn |> ok()
  end

  defp ok(conn),
    do:
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "ok")
end
