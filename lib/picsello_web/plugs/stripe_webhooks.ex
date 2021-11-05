defmodule PicselloWeb.Plugs.StripeWebhooks do
  @moduledoc false
  @behaviour Plug

  def init(config), do: config

  def call(conn, _) do
    signing_secret = Application.get_env(:stripity_stripe, :connect_signing_secret)
    handle_request(conn, signing_secret)
  end

  defp handle_request(conn, signing_secret) do
    [stripe_signature] = Plug.Conn.get_req_header(conn, "stripe-signature")

    {:ok, body, _} = Plug.Conn.read_body(conn)
    {:ok, stripe_event} = payments().construct_event(body, stripe_signature, signing_secret)
    Plug.Conn.assign(conn, :stripe_event, stripe_event)
  end

  def payments, do: Application.get_env(:picsello, :payments)
end
