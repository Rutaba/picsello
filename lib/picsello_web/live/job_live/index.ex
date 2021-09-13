defmodule PicselloWeb.JobLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo}
  require Ecto.Query
  alias Ecto.Query

  @impl true
  def mount(_params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_jobs()
    |> ok()
  end

  @impl true
  def handle_event("create-lead", %{}, socket),
    do:
      socket
      |> open_modal(PicselloWeb.JobLive.NewComponent, Map.take(socket.assigns, [:current_user]))
      |> noreply()

  defp assign_jobs(%{assigns: %{current_user: current_user, live_action: action}} = socket) do
    socket
    |> assign(
      jobs:
        current_user
        |> Job.for_user()
        |> then(fn query ->
          case action do
            :leads -> query |> Job.leads()
            :jobs -> query |> Job.not_leads()
          end
        end)
        |> Query.preload([:client, :package, :shoots, :booking_proposals, :job_status])
        |> Query.order_by(desc: :updated_at)
        |> Repo.all()
    )
  end

  def card_date(:jobs, "" <> time_zone, %Job{shoots: shoots}) do
    try do
      date =
        shoots
        |> Enum.map(& &1.starts_at)
        |> Enum.filter(&(DateTime.compare(&1, DateTime.utc_now()) == :gt))
        |> Enum.min(DateTime)

      strftime(time_zone, date, "%B %d, %Y @ %I:%M %p")
    rescue
      _e in Enum.EmptyError ->
        nil
    end
  end

  def card_date(:leads, _, _), do: nil
end
