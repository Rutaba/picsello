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
      extra_applications: [:logger, :os_mon, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      [
        {:bamboo, "~> 2.2.0"},
        {:bcrypt_elixir, "~> 2.0"},
        {:ecto_psql_extras, "~> 0.2"},
        {:ecto_sql, "~> 3.4"},
        {:gettext, "~> 0.11"},
        {:jason, "~> 1.0"},
        {:money, "~> 1.8"},
        {:phoenix, "~> 1.5.9"},
        {:phoenix_ecto, "~> 4.1"},
        {:phoenix_html, "~> 2.11"},
        {:phoenix_live_dashboard, "~> 0.4"},
        {:phoenix_live_view, "~> 0.15.1"},
        {:plug_cowboy, "~> 2.0"},
        {:postgrex, ">= 0.0.0"},
        {:stripity_stripe, "~> 2.10.0"},
        {:telemetry_metrics, "~> 0.4"},
        {:telemetry_poller, "~> 0.4"}
      ],
      [
        {:dialyxir, "~> 1.0", only: :dev, runtime: false},
        {:phoenix_live_reload, "~> 1.2", only: :dev},
        {:phx_gen_auth, "~> 0.7", only: :dev, runtime: false},
        {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
        {:mox, "~> 1.0.0", only: [:dev, :test]}
      ],
      [
        {:ex_machina, "~> 2.7.0", only: :test},
        {:exexec, ">= 0.2.0", only: :test},
        {:floki, ">= 0.30.0", only: :test},
        {:wallaby, "~> 0.28.0", runtime: false, only: :test}
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
