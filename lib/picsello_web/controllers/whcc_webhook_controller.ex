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
    Picsello.Cart.store_cart_product_processing(params)
    conn.private.raw_body |> IO.inspect(label: "raw body")

    conn |> ok()
  end

  def webhook(
        %Plug.Conn{} = conn,
        %{
          "Event" => "Processed",
          "Status" => "Rejected",
          "Errors" => errors,
          "EntryId" => entry
        } = params
      ) do
    Picsello.Cart.store_cart_product_processing(params)
    Logger.error("[whcc] Error processing #{entry}: #{inspect(errors)}")

    conn |> ok()
  end

  def webhook(
        %Plug.Conn{} = conn,
        %{
          "Event" => "Shipped"
        } = params
      ) do
    Picsello.Cart.store_cart_product_tracking(params)
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
