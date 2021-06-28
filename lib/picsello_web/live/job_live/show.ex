defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo}

  @impl true
  def mount(%{"id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_job(job_id)
    |> maybe_redirect()
    |> ok()
  end

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Repo.get!(job_id)
      |> Repo.preload([:client, :package])

    socket |> assign(:job, job)
  end

  defp maybe_redirect(%{assigns: %{job: %{id: job_id, package_id: nil}}} = socket) do
    socket |> push_redirect(to: Routes.job_package_path(socket, :new, job_id))
  end

  defp maybe_redirect(socket), do: socket
end
