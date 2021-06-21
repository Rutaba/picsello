defmodule PicselloWeb.PackageLive.New do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo}

  @impl true
  def mount(%{"job_id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_job(job_id)
    |> ok()
  end

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job = current_user |> Job.for_user() |> Repo.get!(job_id) |> Repo.preload(:client)

    socket |> assign(:job, job)
  end
end
