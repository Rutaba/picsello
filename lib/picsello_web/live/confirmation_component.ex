defmodule PicselloWeb.ConfirmationComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  @default_assigns %{
    close_label: "Close",
    close_class: "btn-secondary",
    confirm_event: nil,
    close_event: nil,
    confirm_label: "Yes",
    confirm_class: "btn-warning",
    icon: "confetti",
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
    assigns = Enum.into(assigns, %{class: "dialog"})

    ~H"""
    <div class={@class}>
      <%= if @icon do %>
        <.icon name={@icon} class="w-11 h-11" />
      <% end %>

      <h1 class="text-3xl font-semibold">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4 whitespace-pre-wrap"><%= @subtitle %></p>
      <% end %>

      <%= if @confirm_event do %>
        <button class={"w-full mt-6 " <> @confirm_class} title={@confirm_label} type="button" phx-click={@confirm_event} phx-disable-with="Saving&hellip;" phx-target={@myself}>
          <%= @confirm_label %>
        </button>
      <% end %>

      <%= if @close_event do %>
        <button class={"w-full mt-6 " <> @close_class} title={@close_label} type="button" phx-click={"close_event"} phx-target={@myself}>
          <%= @close_label %>
        </button>
        <% else %>
          <button class={"w-full mt-6 " <> @close_class} type="button" phx-click="modal" phx-value-action="close">
            <%= @close_label %>
          </button>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("close_event", %{}, %{assigns: %{parent_pid: parent_pid, close_event: close_event}} = socket) do
    send(parent_pid, {:close_event, close_event})

    socket |> noreply()
  end

  @impl true
  def handle_event(event, %{}, %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket) do
    send(parent_pid, {:confirm_event, event, payload})

    socket |> noreply()
  end

  @impl true
  def handle_event(
        "close_event",
        %{},
        %{assigns: %{parent_pid: parent_pid, close_event: close_event}} = socket
      ) do
    send(parent_pid, {:close_event, close_event})

    socket |> noreply()
  end

  @impl true
  def handle_event(event, %{}, %{assigns: %{parent_pid: parent_pid}} = socket) do
    send(parent_pid, {:confirm_event, event})

    socket |> noreply()
  end

  @spec open(%Phoenix.LiveView.Socket{}, %{
          optional(:close_label) => binary,
          optional(:close_class) => binary,
          optional(:confirm_event) => any,
          optional(:close_event) => any,
          optional(:confirm_label) => binary,
          optional(:confirm_class) => binary,
          optional(:class) => binary | nil,
          optional(:icon) => binary | nil,
          optional(:subtitle) => binary,
          optional(:payload) => map,
          title: binary
        }) :: %Phoenix.LiveView.Socket{}
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
