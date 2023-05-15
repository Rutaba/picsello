defmodule PicselloWeb.Plugs.StripeWebhooks do
  @moduledoc false
  @behaviour Plug

  alias Picsello.Payments
  require Logger

  def init(config), do: config

  def call(%{request_path: "/stripe/connect-webhooks"} = conn, _) do
    Logger.warning("call-------------")
    signing_secret = Application.get_env(:stripity_stripe, :connect_signing_secret)
    Logger.warning("signing_secret-------------: #{inspect(signing_secret)}")
    handle_request(conn, signing_secret)
  end

  def call(%{request_path: "/stripe/app-webhooks"} = conn, _) do
    Logger.warning("call-------------")
    signing_secret = Application.get_env(:stripity_stripe, :app_signing_secret)
    Logger.warning("signing_secret-------------: #{inspect(signing_secret)}")
    handle_request(conn, signing_secret)
  end

  def call(conn, _), do: conn

  defp handle_request(conn, signing_secret) do
    a = Plug.Conn.get_req_header(conn, "stripe-signature")
    Logger.warning("a-------------: #{inspect(a)}")
    [stripe_signature] = a
    Logger.warning("stripe_signature-------------: #{inspect(stripe_signature)}")
    {:ok, body, _} = Plug.Conn.read_body(conn)
    Logger.warning("body-------------: #{inspect(body)}")
    {:ok, stripe_event} = Payments.construct_event(body, stripe_signature, signing_secret)
    Logger.warning("stripe_event-------------: #{inspect(stripe_event)}")
    Plug.Conn.assign(conn, :stripe_event, stripe_event)
  end
end
