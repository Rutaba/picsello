defmodule PicselloWeb.StripeWebhooksController do
  use PicselloWeb, :controller
  require Logger
  alias Picsello.{Cart, PaymentSchedules}

  def connect_webhooks(%Plug.Conn{assigns: %{stripe_event: stripe_event}} = conn, _params) do
    :ok = handle_webhook(:connect, stripe_event)
    success_response(conn)
  end

  def app_webhooks(%Plug.Conn{assigns: %{stripe_event: stripe_event}} = conn, _params) do
    :ok = handle_webhook(:app, stripe_event)
    success_response(conn)
  end

  def handle_webhook(:connect, %{type: "checkout.session.completed", data: %{object: session}}) do
    Logger.info("handling webhook - %{session}")

    {:ok, _} =
      case session.client_reference_id do
        "order_number_" <> _ -> Cart.confirm_order(session, PicselloWeb.Helpers)
        "proposal_" <> _ -> PaymentSchedules.handle_payment(session, PicselloWeb.Helpers)
      end

    Logger.info("handled webhook")
    :ok
  end

  def handle_webhook(:app, %{type: type, data: %{object: subscription}})
      when type in [
             "customer.subscription.created",
             "customer.subscription.updated",
             "customer.subscription.deleted"
           ] do
    {:ok, _} = Picsello.Subscriptions.handle_stripe_subscription(subscription)
    :ok
  end

  defp success_response(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end