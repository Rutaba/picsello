# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :picsello,
  ecto_repos: [Picsello.Repo]

# Configures the endpoint
config :picsello, PicselloWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "3O2nR2CPS892vIiSWKwPap76A5gKmbL6rh5QTYaw+U1hu2bj/nbjeOG70A4sLbXB",
  render_errors: [view: PicselloWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Picsello.PubSub,
  live_view: [signing_salt: "b9Q+efw0"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason
config :money, default_currency: :USD
config :picsello, :modal_transition_ms, 400
config :picsello, :payments, Picsello.StripePayments
config :picsello, :google_site_verification, System.get_env("GOOGLE_SITE_VERIFICATION")

config :stripity_stripe,
  api_key: System.get_env("STRIPE_SECRET"),
  connect_signing_secret: System.get_env("STRIPE_CONNECT_SIGNING_SECRET")

config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

config :gcs_sign,
  gcp_credentials: %{
    "auth_provider_x509_cert_url" => "https://www.googleapis.com/oauth2/v1/certs",
    "auth_uri" => "https://accounts.google.com/o/oauth2/auth",
    "client_email" => "storage-account@celtic-rite-323300.iam.gserviceaccount.com",
    "client_id" => "111011783898360383654",
    "client_x509_cert_url" =>
      "https://www.googleapis.com/robot/v1/metadata/x509/storage-account%40celtic-rite-323300.iam.gserviceaccount.com",
    "private_key" => System.get_env("GCP_PRIVATE_KEY"),
    "private_key_id" => System.get_env("GCP_PRIVATE_KEY_ID"),
    "project_id" => "celtic-rite-323300",
    "token_uri" => "https://oauth2.googleapis.com/token",
    "type" => "service_account"
  }

config :picsello, :whcc_client,
  url: System.get_env("WHCC_URL"),
  key: System.get_env("WHCC_KEY"),
  secret: System.get_env("WHCC_SECRET"),
  token_valid_for: 60 * 90

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
