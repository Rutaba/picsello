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
  chromedriver:
    [
      headless: System.get_env("HEADLESS", "true") == "true"
    ]
    |> then(
      &case System.get_env("CHROME_BINARY") do
        "" <> path -> Keyword.put(&1, :binary, path)
        _ -> &1
      end
    ),
  driver: Wallaby.Chrome,
  otp_app: :picsello,
  screenshot_on_failure: true

config :bamboo, :refute_timeout, 10

config :picsello, Picsello.Mailer,
  adapter: Picsello.MockBambooAdapter,
  contact_list_transactional: "contact-list-transactional-id",
  contact_list_trial_welcome: "contact-list-trial-welcome-id",
  client_transactional_template: "client-transactional-id",
  generic_transactional_template: "generic-transactional-id",
  marketing_template: "marketing-xyz",
  marketing_unsubscribe_id: "123" |> Integer.parse(),
  reply_to_domain: "test-inbox.picsello.com"

config :picsello, sandbox: Picsello.Sandbox
config :picsello, :modal_transition_ms, 0
config :picsello, :debounce, 0
config :picsello, :payments, Picsello.MockPayments
config :picsello, :mox_allow_all, {Picsello.Mock, :allow_all}
config :picsello, :render_test_ids, true

config :stripity_stripe,
  api_key: "sk_test_thisisaboguskey",
  api_base_url: "http://localhost:12111/v1/"

config :ueberauth, Ueberauth, providers: [google: {Picsello.MockAuthStrategy, []}]

config :picsello, :whcc, adapter: Picsello.MockWHCCClient

config :picsello, Oban, queues: false, plugins: false

config :picsello,
       :feature_flags,
       ~w[sync_whcc_design_details show_pricing_tab automated_proposal_emails balance_due_emails]a

config :tesla, adapter: Tesla.Mock

config :picsello, :photo_output_subscription, {Broadway.DummyProducer, []}
config :picsello, :photo_storage_service, Picsello.PhotoStorageMock

config :sentry, environment_name: :test, included_environments: [:prod]

config :picsello, :zapier,
  new_user_webhook_url: "/zapier/1234",
  trial_user_webhook_url: "/zapier/5678",
  subscription_ending_user_webhook_url: "/zapier/91011",
