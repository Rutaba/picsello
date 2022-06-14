defmodule PicselloWeb.WhccWebhookController do
  use PicselloWeb, :controller
  require Logger
  alias Picsello.{WHCC, Orders}

  def webhook(%Plug.Conn{} = conn, %{"verifier" => hash}) do
    WHCC.WebhookKeeper.finish_verification(hash)
    conn |> ok()
  end

  def webhook(%Plug.Conn{} = conn, params) do
    with {:ok, payload} <- WHCC.Webhooks.parse_payload(params),
         {:ok, _order} <- Orders.update_whcc_order(payload, PicselloWeb.Helpers) do
      case payload do
        %{status: "Rejected", errors: errors, entry_id: order_number} ->
          Logger.error("[whcc] Error processing order number #{order_number}: #{inspect(errors)}")

        _ ->
          Logger.info("[whcc] order updated #{inspect(payload)}")
      end
    else
      error ->
        Logger.error("[whcc] could not process webhook #{inspect(params)}: #{inspect(error)}")
    end

    conn |> ok()
  end

  defp ok(conn),
    do:
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "ok")
end
