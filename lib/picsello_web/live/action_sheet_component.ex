defmodule PicselloWeb.ActionSheetComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dialog">
      <h2 class="text-xs font-semibold tracking-widest text-gray-400 uppercase"><%= @title %></h2>
      <%= for %{title: title, action_event: event} <- @actions do %>
        <button class="mt-4 btn-row"
          title={title}
          type="button"
          phx-click={event}
          phx-target={@myself}
        >
          <%= title %>
          <.icon name="forth" class="w-4 h-4 stroke-current stroke-2" />
        </button>
      <% end %>

      <button class="w-full mt-8 btn-secondary" type="button" phx-click="modal" phx-value-action="close">
        Close
      </button>
    </div>
    """
  end

  @impl true
  def handle_event(
        event,
        %{},
        %{assigns: %{parent_pid: parent_pid}} = socket
      ) do
    send(parent_pid, {:action_event, event})

    socket |> noreply()
  end

  @spec open(%Phoenix.LiveView.Socket{}, %{
          actions: [%{title: binary, action_event: any}],
          title: binary
        }) :: %Phoenix.LiveView.Socket{}
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
