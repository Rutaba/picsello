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

config :stripity_stripe,
  api_key: System.get_env("STRIPE_SECRET"),
  connect_signing_secret: System.get_env("STRIPE_CONNECT_SIGNING_SECRET")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
