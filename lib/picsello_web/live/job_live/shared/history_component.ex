defmodule PicselloWeb.JobLive.Shared.HistoryComponent do
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
    ~H"""
    <div class="flex flex-col" role="status">
      <%= if @next_status do %>
        <div class="flex mt-4">
          <div class="w-7 h-7 rounded-full flex items-center justify-center bg-white">
            <.icon name="info-contained" class="text-blue-planning-300 w-4 h-4" />
          </div>
          <span class="ml-4 text-blue-planning-300 font-bold"><%= @next_status %></span>
        </div>
      <% end %>

      <%= if @current_status do %>
        <div class="flex mt-4">
          <div class="w-7 h-7 rounded-full flex items-center justify-center bg-white">
            <.icon name="info-contained" class="text-blue-planning-300 w-4 h-4" />
          </div>
          <div class="flex flex-col ml-4">
            <span class="font-bold"><%= @current_status %></span>
            <span class="text-base-250"><%= @date %></span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp assign_status(socket, %{job: job, current_user: current_user}) do
    %{job_status: job_status} = job |> Repo.preload(:job_status)

    {current_status, next_status} = current_statuses(job_status.current_status)
    date = strftime(current_user.time_zone, job_status.changed_at, "%B %-d, %Y")

    socket
    |> assign(current_status: current_status, next_status: next_status, date: date)
  end

  defp current_statuses(:completed), do: {nil, "Completed"}

  defp current_statuses(:imported), do: {nil, "Active"}

  defp current_statuses(:archived), do: {"Lead archived", nil}

  defp current_statuses(:sent), do: {"Proposal sent", "Awaiting acceptance"}

  defp current_statuses(:not_sent), do: {"Lead created", nil}

  defp current_statuses(:accepted), do: {"Proposal accepted", "Awaiting contract"}

  defp current_statuses(:signed_without_questionnaire),
    do: {"Proposal signed", "Pending payment"}

  defp current_statuses(:signed_with_questionnaire),
    do: {"Proposal signed", "Awaiting questionnaire"}

  defp current_statuses(:answered), do: {"Questionnaire answered", "Pending payment"}

  defp current_statuses(:deposit_paid), do: {nil, "Active"}
end
