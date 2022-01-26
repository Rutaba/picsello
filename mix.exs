defmodule Picsello.MixProject do
  use Mix.Project

  def project do
    [
      app: :picsello,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Picsello.Application, []},
      extra_applications: [:logger, :os_mon, :runtime_tools, :crypto]
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
        {:bamboo, "~> 2.2.0"},
        {:bcrypt_elixir, "~> 2.3"},
        {:ecto_psql_extras, "~> 0.7.2"},
        {:ecto_sql, "~> 3.7"},
        {:elixir_email_reply_parser, "~> 0.1.2"},
        {:gettext, "~> 0.18"},
        {:flow, "~> 1.1"},
        {:jason, "~> 1.2.2"},
        {:libcluster, "~> 3.3"},
        {:money, "~> 1.9"},
        {:mustache, "~> 0.4.0"},
        {:oban, "~> 2.10.1"},
        {:paginator, "~> 1.0.4"},
        {:phoenix, "~> 1.5.12"},
        {:phoenix_ecto, "~> 4.4.0"},
        {:phoenix_html, "~> 3.0.4"},
        {:phoenix_live_dashboard, "~> 0.6.0"},
        {:phoenix_live_view, "~> 0.17.2"},
        {:plug_cowboy, "~> 2.5.2"},
        {:postgrex, ">= 0.0.0"},
        {:stripity_stripe, "~> 2.12.1"},
        {:telemetry_metrics, "~> 0.6.1"},
        {:telemetry_poller, "~> 0.5.1"},
        {:tesla, "~> 1.4.3"},
        {:tz, "~> 0.20"},
        {:tz_extra, "~> 0.20.1"},
        {:ueberauth_google, "~> 0.10"},
        {:packmatic, "~> 1.1.2"},
        {:gcs_sign, "~> 1.0"},
        {:broadway_cloud_pub_sub, "~> 0.7.0"},
        {:goth, "~> 1.0"},
        {:google_api_storage, "~> 0.32.0"},
        {:google_api_sheets, "~> 0.29.2"},
        {:elixir_uuid, "~> 1.2"},
        {:kane, "~> 0.9.0"},
        {:struct_access, "~> 1.1"},
        {:size, "~> 0.1.0"},
        {:cll, "~> 0.1.0"},
        {:ex_zipcodes, "~> 0.1.1"},
        {:ecto_commons, "~> 0.3.3"}
      ],
      [
        {:dialyxir, "~> 1.1.0", only: :dev, runtime: false},
        {:phoenix_live_reload, "~> 1.3.3", only: :dev},
        {:phx_gen_auth, "~> 0.7", only: :dev, runtime: false},
        {:credo, "~> 1.5.6", only: [:dev, :test], runtime: false},
        {:mox, "~> 1.0.0", only: [:dev, :test]}
      ],
      [
        {:ex_machina, "~> 2.7.0", only: [:dev, :test]},
        {:floki, "~> 0.31.0", only: :test},
        {:httpoison, "~> 1.8.0"},
        {:wallaby, "~> 0.29.1", runtime: false, only: :test}
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
