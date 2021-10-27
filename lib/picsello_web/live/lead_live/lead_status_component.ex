defmodule PicselloWeb.LeadLive.LeadStatusComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign_status(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="flex mt-2" role="status">
      <%= if @next_status do %>
        <div class="p-2 mr-2 font-bold border rounded-lg text-blue-planning-300 border-blue-planning-300">
          <%= @next_status %>
        </div>
      <% end %>

      <div class="flex overflow-hidden font-bold border rounded-lg text-blue-planning-300 border-blue-planning-300">
        <div class="flex flex-col items-center justify-center px-2 mr-2 text-xs font-semibold text-white bg-blue-planning-300">
          <div class="uppercase"><%= @month %></div>

          <div><%= @day %></div>
        </div>

        <div class="flex items-center pr-2"><%= @current_status %></div>
      </div>
    </div>
    """
  end

  defp assign_status(socket, %{job: job, current_user: current_user}) do
    %{job_status: job_status} = job |> Repo.preload(:job_status)

    {current_status, next_status} = current_statuses(job_status.current_status)
    month = strftime(current_user.time_zone, job_status.changed_at, "%b")
    day = strftime(current_user.time_zone, job_status.changed_at, "%d")

    socket
    |> assign(current_status: current_status, next_status: next_status, month: month, day: day)
  end

  defp current_statuses(:archived), do: {"Lead archived", nil}

  defp current_statuses(:sent), do: {"Proposal sent", "Awaiting acceptance"}

  defp current_statuses(:not_sent), do: {"Lead created", nil}

  defp current_statuses(:accepted), do: {"Proposal accepted", "Awaiting contract"}

  defp current_statuses(:signed_without_questionnaire),
    do: {"Proposal signed", "Pending payment"}

  defp current_statuses(:signed_with_questionnaire),
    do: {"Proposal signed", "Awaiting questionnaire"}

  defp current_statuses(:answered), do: {"Questionnaire answered", "Pending payment"}

  defp current_statuses(:deposit_paid), do: {"Payment paid", "Job created"}
end
