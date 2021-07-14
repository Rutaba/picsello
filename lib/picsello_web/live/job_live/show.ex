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
  def handle_info({:update, assigns}, socket),
    do: socket |> assign(assigns) |> noreply()

  @impl true
  def handle_info({:update_shoot_count, op}, %{assigns: %{shoot_count: shoot_count}} = socket) do
    shoot_count =
      case op do
        :inc -> shoot_count + 1
        :dec -> shoot_count - 1
      end

    socket |> assign(shoot_count: shoot_count) |> noreply()
  end

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Repo.get!(job_id)
      |> Repo.preload([:client, :package, :shoots])

    socket
    |> assign(
      job: job |> Map.drop([:shoots, :package]),
      package: job.package,
      shoot_count: job.shoots |> Enum.count()
    )
  end
end
