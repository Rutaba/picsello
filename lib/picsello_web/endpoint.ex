defmodule PicselloWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :picsello

  with sandbox when sandbox != nil <- Application.compile_env(:picsello, :sandbox) do
    plug Phoenix.Ecto.SQL.Sandbox, sandbox: sandbox
  end

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_picsello_key",
    signing_salt: "yvn6g2IQ"
  ]

  socket "/socket", PicselloWeb.UserSocket,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:uri, :user_agent, {:session, @session_options}]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :picsello,
    gzip: false,
    only: ~w(css fonts images js robots.txt),
    only_matching: ~w(favicon apple-touch-icon mstile manifest)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :picsello
  end

  plug CORSPlug, origin: [~r/.*/]

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug PicselloWeb.Plugs.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug PicselloWeb.Plugs.StripeWebhooks

  plug PicselloWeb.Plugs.WhccWebhook

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    length: Application.compile_env!(:picsello, :plug_parser_length),
    json_decoder: Phoenix.json_library()

  plug Sentry.PlugContext
  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session, @session_options
  plug PicselloWeb.Router
end
