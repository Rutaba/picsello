defmodule Picsello.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # Start libCluster
      {Cluster.Supervisor, [topologies, [name: Picsello.ClusterSupervisor]]},
      ImageProcessing.TaskKeeper,
      ImageProcessing.TaskProxy,
      ImageProcessing.Flow,
      # Start the Ecto repository
      Picsello.Repo,
      # Start the Telemetry supervisor
      PicselloWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Picsello.PubSub},
      # Start the Endpoint (http/https)
      PicselloWeb.Endpoint,
      {Picsello.ProposalReminderScheduler, []},
      {Picsello.StripeStatusCache, []},
      Picsello.WHCC.Client.TokenStore,
      # Start a worker by calling: Picsello.Worker.start_link(arg)
      # {Picsello.Worker, arg}
      # Gallery workers
      Picsello.Galleries.Workers.PositionNormalizer
    ]

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
