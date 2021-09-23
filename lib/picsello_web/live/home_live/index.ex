defmodule PicselloWeb.HomeLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo}
  require Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Work Hub")
    |> assign_counts()
    |> ok()
  end

  @impl true
  def handle_event("create-lead", %{}, socket),
    do:
      socket
      |> open_modal(PicselloWeb.JobLive.NewComponent, Map.take(socket.assigns, [:current_user]))
      |> noreply()

  defp assign_counts(%{assigns: %{current_user: current_user}} = socket) do
    [lead_count, job_count] =
      current_user
      |> Job.for_user()
      |> Ecto.Query.preload([:booking_proposals, :job_status])
      |> Repo.all()
      |> Enum.split_with(&Job.lead?/1)
      |> Tuple.to_list()
      |> Enum.map(&Enum.count/1)

    socket |> assign(lead_count: lead_count, job_count: job_count)
  end
end
