defmodule PicselloWeb.WhccWebhookController do
  use PicselloWeb, :controller
  require Logger
  alias Picsello.WHCC

  def webhook(%Plug.Conn{} = conn, %{"verifier" => hash}) do
    %{"isVerified" => true} = WHCC.webhook_verify(hash)
    Logger.info("[whcc] Webhook registered successfully")
    conn |> ok()
  end

  def webhook(
        %Plug.Conn{} = conn,
        %{
          "EntryId" => entry,
          "Status" => "Accepted"
        } = params
      ) do
    Picsello.Cart.store_cart_product_processing(params)
    Logger.info("[whcc] Processed #{entry}")

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
          "EntryId" => entry,
          "Event" => "Shipped"
        } = params
      ) do
    Picsello.Cart.store_cart_product_tracking(params)
    Logger.info("[whcc] Shipped #{entry}")
    conn |> ok()
  end

  def webhook(%Plug.Conn{} = conn, params) do
    Logger.warn("[whcc] Unknown webhook: #{inspect(params)}")

    conn |> ok()
  end

  defp ok(conn),
    do:
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "ok")
end
