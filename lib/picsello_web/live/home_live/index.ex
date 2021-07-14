defmodule PicselloWeb.HomeLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo}
  alias PicselloWeb.Modal

  @impl true
  def mount(_params, session, socket) do
    socket |> assign_defaults(session) |> assign_job_count() |> ok()
  end

  @impl true
  def handle_event("create-lead", %{}, socket),
    do:
      socket
      |> open_modal(PicselloWeb.JobLive.NewComponent, Map.take(socket.assigns, [:current_user]))
      |> noreply()

  defp assign_job_count(%{assigns: %{current_user: current_user}} = socket) do
    assign(socket, job_count: current_user |> Job.for_user() |> Repo.aggregate(:count))
  end
end
