defmodule PicselloWeb.StripeConnectWebhooksController do
  use PicselloWeb, :controller
  require Logger
  alias Picsello.Payments

  def webhooks(%Plug.Conn{assigns: %{stripe_event: stripe_event}} = conn, _params) do
    :ok = handle_webhook(stripe_event)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end

  def handle_webhook(%{type: "checkout.session.completed", data: %{object: session}}) do
    Logger.info("handling webhook - %{session}")
    {:ok, _} = Payments.handle_payment(session)

    Logger.info("handled webhook")
    :ok
  end
end
