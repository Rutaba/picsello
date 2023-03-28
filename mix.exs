defmodule Picsello.MixProject do
  use Mix.Project

  def project do
    [
      app: :picsello,
      version: "0.1.0",
      elixir: "~> 1.14.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix], plt_file: {:no_warn, "priv/plts/dialyzer.plt"}]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Picsello.Application, []},
      extra_applications: [:logger, :os_mon, :runtime_tools, :crypto, :pdf_generator]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp elixirc_paths(:dev),
    do: ["lib", "test/support/factory.ex", "test/support/save_fixtures.ex"]

  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      [
        # {:bamboo, "~> 2.2.0"},
        {:bamboo, "~> 2.3"},
        # {:bcrypt_elixir, "~> 2.3"}, major
        {:bcrypt_elixir, "~> 3.0"},
        {:ecto_psql_extras, "~> 0.7.2"},
        {:ecto_sql, "~> 3.7"},
        {:elixir_email_reply_parser, "~> 0.1.2"},
        {:gettext, "~> 0.18"},
        {:html_sanitize_ex, "~> 1.4"},
        {:flow, "~> 1.1"},
        {:jason, "~> 1.4"},
        # {:jason, "~> 1.2.2"},
        {:libcluster, "~> 3.3"},
        # {:money, "~> 1.9"},
        {:money, "~> 1.12"},
        {:bbmustache, "~> 1.12"},
        # {:oban, "~> 2.10.1"}, changelog
        {:oban, "~> 2.14"},
        # {:paginator, "~> 1.0.4"}, changelog
        {:paginator, "~> 1.2"},
        # {:phoenix, "~> 1.5.12"},
        {:phoenix, "~> 1.7"},
        {:phoenix_ecto, "~> 4.4"},
        # {:phoenix_ecto, "~> 4.4.0"},
        # {:phoenix_html, "~> 3.2.0"},
        {:phoenix_html, "~> 3.3"},
        # {:phoenix_live_dashboard, "~> 0.6.2"},need to fix
        {:phoenix_live_dashboard, "~> 0.7.2"},
        {:phoenix_live_view, "~> 0.18.18"},
        # {:phoenix_live_view, "~> 0.17.6"},
        # {:plug_cowboy, "~> 2.5.2"},
        {:plug_cowboy, "~> 2.6"},
        {:postgrex, ">= 0.0.0"},
        # {:stripity_stripe, "~> 2.15.0"},
        {:stripity_stripe, "~> 2.17"},
        {:telemetry_metrics, "~> 0.6.1"},
        {:telemetry_poller, "~> 1.0"},
        # {:telemetry_poller, "~> 0.5.1"}, need to fix
        # {:tesla, "~> 1.4.3"},
        {:tesla, "~> 1.5"},
        {:tz, "~> 0.20"},
        {:tz_extra, "~> 0.25.0"},
        # {:tz_extra, "~> 0.20.1"},
        {:ueberauth_google, "~> 0.10"},
        {:packmatic, "~> 1.1.2"},
        {:gcs_sign, "~> 1.0"},
        # {:broadway_cloud_pub_sub, "~> 0.7.0"}, major
        {:broadway_cloud_pub_sub, "~> 0.8.0"},
        {:goth, "~> 1.0"},
        # {:google_api_pub_sub, "~> 0.34.1"}, major
        {:google_api_pub_sub, "~> 0.36.0"},
        # {:google_api_storage, "~> 0.32.0"}, major
        {:google_api_storage, "~> 0.34.0"},
        {:google_api_sheets, "~> 0.29.2"},
        {:elixir_uuid, "~> 1.2"},
        # {:kane, "~> 0.9.0"}, major
        {:kane, "~> 1.0"},
        {:sentry, "~> 8.0"},
        {:struct_access, "~> 1.1"},
        {:size, "~> 0.1.0"},
        # {:cll, "~> 0.1.0"}, major
        {:cll, "~> 0.2.0"},
        {:ecto_commons, "~> 0.3.3"},
        # {:cors_plug, "~> 2.0"}, changelog, major
        {:cors_plug, "~> 3.0"},
        {:floki, "~> 0.32"},
        {:icalendar, "~> 1.1.0"},
        # {:con_cache, "~> 0.13"}, changelog, major
        {:con_cache, "~> 1.0"},
        {:pdf_generator, ">=0.6.0"}
      ],
      [
        # {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false}, changelog
        {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
        # {:phoenix_live_reload, "~> 1.3.3", only: :dev},
        {:phoenix_live_reload, "~> 1.4", only: :dev},
        # {:phx_gen_auth, "~> 0.7", only: :dev, runtime: false},
        {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
        # {:credo, "~> 1.5.6", only: [:dev, :test], runtime: false}, changelog
        {:mox, "~> 1.0.0", only: [:dev, :test]}
      ],
      [
        {:bypass, "~> 2.1", only: :test},
        {:ex_machina, "~> 2.7.0", only: [:dev, :test]},
        # {:httpoison, "~> 2.1"},changelog, need to fix
        {:httpoison, "~> 1.8.0"},
        {:wallaby, "~> 0.30.2", runtime: false, only: :test},
        # {:wallaby, "~> 0.29.1", runtime: false, only: :test},
        # {:csv, "~> 2.4"} major
        {:csv, "~> 3.0"}
      ]
    ]
    |> Enum.concat()
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
