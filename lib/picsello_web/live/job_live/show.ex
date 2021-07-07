defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo}

  @impl true
  def mount(%{"id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_job(job_id)
    |> ok()
  end

  @impl true
  def handle_info({:updated_job, job}, socket), do: socket |> assign(job: job) |> noreply()

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Repo.get!(job_id)
      |> Repo.preload([:client, :package])

    socket |> assign(job: job)
  end
end
