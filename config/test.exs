use Mix.Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :picsello, Picsello.Repo,
  username: "postgres",
  password: "postgres",
  database: "picsello_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 25

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :picsello, PicselloWeb.Endpoint,
  http: [port: 4002],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn

config :wallaby,
  chromedriver: [headless: System.get_env("HEADLESS", "true") == "true"],
  driver: Wallaby.Chrome,
  otp_app: :picsello,
  screenshot_on_failure: true

config :picsello, Picsello.Mailer, adapter: Picsello.Sandbox.BambooAdapter

config :bamboo, :refute_timeout, 10

config :picsello, sandbox: Picsello.Sandbox
