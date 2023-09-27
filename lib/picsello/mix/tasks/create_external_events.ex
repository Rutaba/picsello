defmodule Mix.Tasks.CreateExternalEvents do
  @moduledoc false

  alias Picsello.{Repo, Shoots, Shoot}
  import Ecto.Query

  use Mix.Task

  @shortdoc "Create events to external calendar against existing shoots"
  def run(_) do
    load_app()

    get_shoots()
    |> Shoots.load_user()
    |> Task.async_stream(&Shoots.create_event(&1), max_concurrency: 100, timeout: 10_000)
    |> Stream.run()
  end

  defp get_shoots() do
    from(shoot in Shoot,
      join: job in assoc(shoot, :job),
      join: status in assoc(job, :job_status),
      join: client in assoc(job, :client),
      join: org in assoc(client, :organization),
      join: user in assoc(org, :user),
      join: nylas in assoc(user, :nylas_detail),
      where:
        is_nil(shoot.external_event_id) and is_nil(job.archived_at) and
          is_nil(job.completed_at) and not is_nil(nylas.account_id) and
          (status.is_lead == false or is_nil(job.booking_event_id))
    )
    |> Repo.all()
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
