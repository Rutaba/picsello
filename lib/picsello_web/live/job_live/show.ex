defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Job

  @impl true
  def mount(%{"id" => job_id}, _session, socket) do
    socket
    |> assign_job(job_id)
    |> assign_proposal()
    |> ok()
  end

  def overview_card(assigns) do
    ~H"""
      <li class="flex flex-col justify-between p-4 border rounded-lg">
        <div>
          <div class="mb-6 font-bold">
            <.icon name={@icon} class="inline w-5 h-6 mr-2 stroke-current" />
            <%= @title %>
          </div>

          <%= render_block(@inner_block) %>
        </div>

        <button type="button" class="w-full p-2 mt-6 text-sm text-center border border-black rounded-lg" >
          <%= @button_text %>
        </button>
      </li>
    """
  end

  def circle(assigns) do
    radiuses = %{"7" => "w-7 h-7", "8" => "w-8 h-8"}

    assigns =
      assigns
      |> Enum.into(%{
        class: nil,
        radius_class: Map.get(radiuses, assigns.radius)
      })

    ~H"""
      <div class={"flex items-center justify-center rounded-full bg-blue-primary #{@radius_class} #{@class}"}>
        <%= render_block(@inner_block) %>
      </div>
    """
  end

  def details_item(assigns) do
    ~H"""
    <a class="flex items-center p-2 rounded cursor-pointer hover:bg-blue-light-primary" phx-click="open-proposal" phx-value-action={@action} title={@title}>
      <.circle radius="8" class="flex-shrink-0">
        <.icon name={@icon} width="14" height="14" />
      </.circle>
      <div class="ml-2">
        <div class="flex items-center font-bold">
          <%= @title %>
          <.icon name="forth" class="w-3 h-3 ml-2 text-black stroke-current" />
        </div>
        <div class="text-xs text-gray-500"><%= @status %> — <span class="whitespace-nowrap"><%= strftime(@current_user.time_zone, @date, "%B %d, %Y") %></span></div>
      </div>
    </a>
    """
  end

  @impl true
  def handle_event(
        "open-proposal",
        %{"action" => "details"},
        %{assigns: %{proposal: proposal}} = socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.ProposalComponent.open_modal_from_proposal(proposal)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-proposal",
        %{"action" => "contract"},
        %{assigns: %{proposal: proposal}} = socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.ContractComponent.open_modal_from_proposal(proposal)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-proposal",
        %{"action" => "questionnaire"},
        %{assigns: %{proposal: proposal}} = socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.QuestionnaireComponent.open_modal_from_proposal(proposal)
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared
  defdelegate assign_job(socket, job_id), to: PicselloWeb.JobLive.Shared
  defdelegate assign_proposal(socket), to: PicselloWeb.JobLive.Shared
end
