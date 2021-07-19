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
  def handle_event("add-package", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.PackageLive.NewComponent,
        assigns |> Map.take([:current_user, :job])
      )
      |> noreply()

  @impl true
  def handle_event("edit-package", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.PackageLive.EditComponent,
        assigns |> Map.take([:current_user, :package, :job])
      )
      |> noreply()

  @impl true
  def handle_event("edit-job", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.JobLive.EditComponent,
        assigns |> Map.take([:current_user, :package, :job])
      )
      |> noreply()

  @impl true
  def handle_info({:update, assigns}, socket),
    do: socket |> assign(assigns) |> noreply()

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Repo.get!(job_id)
      |> Repo.preload([:client, :package])

    socket
    |> assign(
      job: job |> Map.drop([:package]),
      package: job.package
    )
  end
end
