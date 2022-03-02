# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

with dotenv = "#{__DIR__}/../.env",
     {:ok, data} <- File.read(dotenv),
     do:
       for(
         "export" <> kv <- String.split(data, "\n"),
         [k, v] = String.split(kv, "=", parts: 2),
         do: k |> String.trim() |> System.put_env(v)
       )

with "" <> base64 <- System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON_BASE64"),
     {:ok, json} <- base64 |> String.trim() |> Base.decode64() do
  config :goth, json: json
end

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
config :picsello, :google_analytics_api_key, System.get_env("GOOGLE_ANALYTICS_API_KEY")
config :picsello, :google_tag_manager_api_key, System.get_env("GOOGLE_TAG_MANAGER_API_KEY")
config :picsello, :help_scout_id, System.get_env("HELP_SCOUT_ID")
config :picsello, :help_scout_id_business, System.get_env("HELP_SCOUT_ID_BUSINESS")

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

add_suffix = fn key ->
  [
    System.get_env(key),
    System.get_env("RENDER_EXTERNAL_URL", "") |> URI.parse() |> Map.get(:host)
  ]
  |> Enum.reject(&is_nil/1)
  |> Enum.join("--")
end

config :picsello,
  photo_output_subscription: {
    BroadwayCloudPubSub.Producer,
    subscription: add_suffix.("PHOTO_PROCESSING_OUTPUT_SUBSCRIPTION"), on_failure: :nack
  },
  photo_processing_input_topic: System.get_env("PHOTO_PROCESSING_INPUT_TOPIC"),
  photo_processing_output_topic: add_suffix.("PHOTO_PROCESSING_OUTPUT_TOPIC"),
  photo_storage_bucket: System.get_env("PHOTO_STORAGE_BUCKET")

config :picsello, :whcc,
  adapter: Picsello.WHCC.Client,
  url: System.get_env("WHCC_URL"),
  key: System.get_env("WHCC_KEY"),
  secret: System.get_env("WHCC_SECRET"),
  webhook_url:
    System.get_env(
      "WHCC_WEBHOOK_URL",
      case System.get_env("RENDER_EXTERNAL_URL") do
        nil -> ""
        host -> host <> "/whcc/webhook"
      end
    )

config :picsello, Oban,
  repo: Picsello.Repo,
  queues: [default: 10, storage: 10, campaigns: 10],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60},
    {Oban.Plugins.Cron,
     crontab: [
       {"*/10 * * * *", Picsello.Workers.SendProposalReminder},
       {"0 0 * * 0", Picsello.Workers.SyncWHCCCatalog}
     ]}
  ]

config :picsello, :packages,
  calculator: [
    sheet_id: System.get_env("PACKAGES_CALCULATOR_SHEET_ID"),
    prices: System.get_env("PACKAGES_CALCULATOR_PRICES_RANGE"),
    cost_of_living: System.get_env("PACKAGES_CALCULATOR_COST_OF_LIVING_RANGE")
  ]

config :picsello, :profile_images,
  bucket: System.get_env("PUBLIC_BUCKET"),
  static_host: System.get_env("GOOGLE_PUBLIC_IMAGE_HOST")

config :picsello, :email_presets,
  sheet_id: System.get_env("EMAIL_PRESET_SHEET_ID"),
  type_ranges: System.get_env("EMAIL_PRESET_TYPE_RANGES"),
  column_map: System.get_env("EMAIL_PRESET_COLUMN_MAP")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
