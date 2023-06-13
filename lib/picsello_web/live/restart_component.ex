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
    <button phx-click="restart_tour" phx-target={@myself} id="start-tour" class="flex items-center px-2 pb-2 bg-white text-base-250">
      <.icon name="refresh-icon" class="w-4 h-4 mr-1" />
      <div class="text-base-250 text-sm ml-2">Restart Product Tours</div>
    </button>
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

  @impl true
  def handle_event("restart_tour", _, socket), do: socket |> noreply()
end
