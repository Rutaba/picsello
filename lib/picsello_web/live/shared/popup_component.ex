defmodule PicselloWeb.Shared.PopupComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1]

  @default_assigns %{
    close_label: "Close",
    close_class: "btn-secondary",
    confirm_event: nil,
    confirm_label: "Yes",
    confirm_class: "btn-primary text-center",
    subtitle: nil
  }

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(Enum.into(assigns, @default_assigns))
    |> ok()
  end

  @impl true
  def render(assigns) do
    assigns = Enum.into(assigns, %{class: "dialog relative"})

    ~H"""
    <div class={@class}>
      <.close_x />
      <h1 class="text-3xl font-bold">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4"><%= raw(@subtitle) %></p>
      <% end %>

      <.section {assigns} />

      <button class="w-full mt-4 px-6 py-3 font-medium text-base-300 bg-white border border-base-300 rounded-lg hover:bg-base-300/10 focus:outline-none focus:ring-2 focus:ring-base-300/70 focus:ring-opacity-75" type="button" phx-click="modal" phx-value-action="close">
        <%= @close_label %>
      </button>
    </div>
    """
  end

  defp section(%{module_component: module_component} = assigns) do
    module_component.section(assigns)
  end

  @impl true
  def handle_event(event, params, %{assigns: %{parent_pid: parent_pid}} = socket) do
    send(parent_pid, {:confirm_event, event, params})

    socket |> noreply()
  end

  @spec open(Phoenix.LiveView.Socket.t(), %{
          optional(:close_label) => binary,
          optional(:close_class) => binary,
          optional(:class) => binary,
          optional(:confirm_event) => any,
          optional(:confirm_label) => binary,
          optional(:confirm_class) => binary,
          optional(:title) => binary,
          optional(:subtitle) => binary,
          optional(:opts) => map,
          module_component: atom(),
          title: binary
        }) :: Phoenix.LiveView.Socket.t()
  def open(socket, %{module_component: _} = assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
