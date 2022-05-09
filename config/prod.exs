use Mix.Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix phx.digest` task,
# which you should run after static files are built and
# before starting your production server.
config :picsello, PicselloWeb.Endpoint,
  url: [
    host:
      System.get_env("EXTERNAL_HOSTNAME") || System.get_env("RENDER_EXTERNAL_HOSTNAME") ||
        "localhost",
    port: 443,
    scheme: "https"
  ],
  debug_errors: System.get_env("DEBUG_ERRORS") == "true",
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info

dns_name = System.get_env("RENDER_DISCOVERY_SERVICE")
app_name = System.get_env("RENDER_SERVICE_NAME")

config :libcluster,
  topologies: [
    render: [
      strategy: Cluster.Strategy.Kubernetes.DNS,
      config: [
        service: dns_name,
        application_name: app_name
      ]
    ]
  ]

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section and set your `:url` port to 443:
#
#     config :picsello, PicselloWeb.Endpoint,
#       ...
#       url: [host: "example.com", port: 443],
#       https: [
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#         certfile: System.get_env("SOME_APP_SSL_CERT_PATH"),
#         transport_options: [socket_opts: [:inet6]]
#       ]
#
# The `cipher_suite` is set to `:strong` to support only the
# latest and more secure SSL ciphers. This means old browsers
# and clients may not be supported. You can set it to
# `:compatible` for wider support.
#
# `:keyfile` and `:certfile` expect an absolute path to the key
# and cert in disk or a relative path inside priv, for example
# "priv/ssl/server.key". For all supported SSL configuration
# options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
#
# We also recommend setting `force_ssl` in your endpoint, ensuring
# no data is ever sent via http, always redirecting to https:
#
#     config :picsello, PicselloWeb.Endpoint,
#       force_ssl: [hsts: true]
#
# Check `Plug.SSL` for all available options in `force_ssl`.

# Finally import the config/prod.secret.exs which loads secrets
# and configuration from environment variables.
# import_config "prod.secret.exs"

config :picsello, Picsello.Mailer,
  adapter: Bamboo.SendGridAdapter,
  api_key: System.get_env("SENDGRID_API_KEY"),
  confirmation_instructions_template:
    System.get_env("SENDGRID_CONFIRMATION_INSTRUCTIONS_TEMPLATE"),
  password_reset_template: System.get_env("SENDGRID_PASSWORD_RESET_TEMPLATE"),
  update_email_template: System.get_env("SENDGRID_UPDATE_EMAIL_TEMPLATE"),
  booking_proposal_template: System.get_env("SENDGRID_BOOKING_PROPOSAL_TEMPLATE"),
  calculator_template: System.get_env("SENDGRID_CALCULATOR_TEMPLATE"),
  generic_transactional_template: System.get_env("SENDGRID_GENERIC_TRANSACTIONAL_TEMPLATE"),
  email_template: System.get_env("SENDGRID_EMAIL_TEMPLATE"),
  reply_to_domain: System.get_env("SENDGRID_REPLY_TO_DOMAIN"),
  order_confirmation_template: System.get_env("SENDGRID_ORDER_CONFIMATION_TEMPLATE"),
  hackney_opts: [
    recv_timeout: :timer.minutes(1)
  ]

config :picsello, :google_maps_api_key, System.get_env("GOOGLE_MAPS_API_KEY")
