defmodule Picsello.Release do
  @app :picsello
  require Logger
  @moduledoc "utilities used to prepare the environment"

  def prepare() do
    migrate()
    ensure_pubsub()
  end

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def ensure_pubsub() do
    :ok = load_app()
    {:ok, _} = Application.ensure_all_started(:tesla)
    {:ok, _} = Application.ensure_all_started(:goth)
    {:ok, _} = create_topic()
    {:ok, _} = create_subscription()

    :ok
  end

  def create_subscription(), do: create_subscription(project_id(), subscription_id(), topic_id())

  def create_subscription(project_id, subscription_id, topic_id) do
    topic = Path.join(["projects", project_id, "topics", topic_id])

    Logger.info(
      "Create subscription #{subscription_id} to topic #{topic_id} in project #{project_id}"
    )

    pub_sub_connection()
    |> GoogleApi.PubSub.V1.Api.Projects.pubsub_projects_subscriptions_create(
      project_id,
      subscription_id,
      body: %GoogleApi.PubSub.V1.Model.Subscription{topic: topic}
    )
    |> case do
      {:ok, _} -> {:ok, subscription_id}
      {:error, %{status: 409}} -> {:ok, subscription_id}
    end
  end

  def create_topic(), do: create_topic(project_id(), topic_id())

  def create_topic(project_id, topic_id) do
    topic = Path.join(["projects", project_id, "topics", topic_id])

    Logger.info("Create topic #{topic_id} in project #{project_id}")

    pub_sub_connection()
    |> GoogleApi.PubSub.V1.Api.Projects.pubsub_projects_topics_create(project_id, topic_id,
      body: %{name: topic}
    )
    |> case do
      {:ok, _} -> {:ok, topic_id}
      {:error, %{status: 409}} -> {:ok, topic_id}
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_loaded(@app)
  end

  defp gcs_token() do
    credentials = Application.get_env(:picsello, :goth_json) |> Jason.decode!()
    Goth.start_link(name: Picsello.Goth, source: {:service_account, credentials, scopes: ["https://www.googleapis.com/auth/cloud-platform"]})
    {:ok, token} = Goth.fetch(Picsello.Goth)
    token.token
  end

  defp pub_sub_connection, do: gcs_token() |> GoogleApi.PubSub.V1.Connection.new()

  defp project_id do
    {:ok, project_id} = Goth.Config.get(:project_id)
    project_id
  end

  defp subscription_id,
    do:
      Application.get_env(:picsello, :photo_output_subscription)
      |> elem(1)
      |> Keyword.get(:subscription)
      |> Path.basename()

  defp topic_id, do: Application.get_env(:picsello, :photo_processing_output_topic)
end
