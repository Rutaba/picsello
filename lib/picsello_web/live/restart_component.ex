defmodule PicselloWeb.Live.RestartTourComponent do
  @moduledoc "restart tour"
  use PicselloWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center bg-white text-base-250 px-1 py-2 justify-start">
      <.icon name="refresh-icon" class="w-3 h-3 mr-1" />
      <button class="text-xs block" phx-click="restart_tour" phx-target={@myself} id="start-tour">Restart Product Tours</button>
    </div>
    """
  end

  @impl true
  def handle_event(
        "restart_tour",
        _,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    Picsello.Onboardings.restart_intro_state(current_user)

    socket
    |> noreply()
  end
end
