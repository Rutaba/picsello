import Config

# Configure your database
config :picsello, Picsello.Repo,
  username: "postgres",
  password: "postgres",
  database: "picsello_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :picsello, PicselloWeb.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: System.get_env("DEBUG_ERRORS", "true") == "true",
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :picsello, PicselloWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/picsello_web/(live|views)/.*(ex)$",
      ~r"lib/picsello_web/templates/.*(eex)$",
      ~r"lib/picsello/.*(ex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n", infinity: true

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :picsello, Picsello.Mailer,
  adapter: Bamboo.SendgridLocalAdapter,
  api_key: System.get_env("SENDGRID_API_KEY"),
  reply_to_domain: System.get_env("SENDGRID_REPLY_TO_DOMAIN", "dev-inbox.picsello.com"),
  download_being_prepared_photog: System.get_env("SENDGRID_DOWNLOAD_BEING_PREPARED_PHOTOG"),
  client_transactional_template: System.get_env("SENDGRID_CLIENT_TRANSACTIONAL_TEMPLATE"),
  generic_transactional_template: System.get_env("SENDGRID_GENERIC_TRANSACTIONAL_TEMPLATE"),
  download_ready_photog: System.get_env("SENDGRID_DOWNLOAD_READY_PHOTOG")

config :picsello, :google_maps_api_key, System.get_env("GOOGLE_MAPS_API_KEY")

config :picsello, :render_test_ids, true

config :picsello,
       :feature_flags,
       ~w[sync_whcc_design_details show_pricing_tab automated_proposal_emails balance_due_emails]a
