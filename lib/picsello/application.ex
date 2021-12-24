defmodule Picsello.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []
    producer_module = Application.get_env(:picsello, :photo_output_subscription)

    children = [
      # Start libCluster
      {Cluster.Supervisor, [topologies, [name: Picsello.ClusterSupervisor]]},
      # Start the Ecto repository
      Picsello.Repo,
      # Start the Telemetry supervisor
      PicselloWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Picsello.PubSub},
      # Start the Endpoint (http/https)
      PicselloWeb.Endpoint,
      {Picsello.StripeStatusCache, []},
      Picsello.WHCC.Client.TokenStore,
      {Oban, Application.fetch_env!(:picsello, Oban)},
      # Start a worker by calling: Picsello.Worker.start_link(arg)
      # {Picsello.Worker, arg}
      # Gallery workers
      Picsello.Galleries.Workers.PositionNormalizer,
      {Picsello.Galleries.PhotoProcessing.ProcessedConsumer, [producer_module: producer_module]}
    ]

    events = [[:oban, :job, :start], [:oban, :job, :stop], [:oban, :job, :exception]]

    :telemetry.attach_many("oban-logger", events, &Picsello.ObanLogger.handle_event/4, [])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Picsello.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PicselloWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
