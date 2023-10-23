defmodule Mix.Tasks.UncompleteFutureJobs do
  @moduledoc """
  Uncomplete jobs that have shoots after 2023-10-17
  """

  use Mix.Task
  require Logger
  import Ecto.Query

  alias Picsello.{
    Repo,
    Job,
    Accounts.User
  }

  @shortdoc "Set completed_at to null for records with dates greater than 2023-10-17; fixes some automations clean up issues"
  def run(_) do
    load_app()

    from(o in Picsello.Organization, select: %{id: o.id})
    |> Repo.all()
    |> Enum.map(fn org ->
      user = %User{organization_id: org.id}

      jobs =
        user
        |> Job.for_user()
        |> Job.not_leads()
        |> select_jobs()

      Enum.map(jobs, fn job ->
        if any_shoots_after_10_17_2023(job) do
          Logger.info("Uncompleting job #{job.id} for organization #{org.id}")
          job |> Job.uncomplete_changeset() |> Repo.update()
        end
      end)
    end)
  end

  defp select_jobs(query) do
    from(j in query, preload: [:job_status, :shoots])
    |> Repo.all()
    |> Enum.filter(&(!is_nil(&1.completed_at)))
  end

  defp any_shoots_after_10_17_2023(%Job{shoots: shoots}) do
    if Enum.empty?(shoots) do
      false
    else
      reference_date = ~D[2023-10-17]

      Enum.any?(shoots, fn shoot ->
        Timex.diff(shoot.starts_at, reference_date, :days) > 0
      end)
    end
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
