defmodule PicselloWeb.Plugs.StripeWebhooks do
  @moduledoc false
  @behaviour Plug

  def init(config), do: config

  def call(%{request_path: "/stripe/connect-webhooks"} = conn, _) do
    signing_secret = Application.get_env(:stripity_stripe, :connect_signing_secret)
    handle_request(conn, signing_secret)
  end

  def call(conn, _), do: conn

  defp handle_request(conn, signing_secret) do
    [stripe_signature] = Plug.Conn.get_req_header(conn, "stripe-signature")

    {:ok, body, _} = Plug.Conn.read_body(conn)
    {:ok, stripe_event} = Stripe.Webhook.construct_event(body, stripe_signature, signing_secret)
    Plug.Conn.assign(conn, :stripe_event, stripe_event)
  end
end
