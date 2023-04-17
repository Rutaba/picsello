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
    subtitle: nil,
    opened_for: nil,
    external_link: nil
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
      <%= if @icon && @icon != "no-icon" do %>
        <.icon name={@icon} class="w-11 h-11" />
      <% end %>

      <h1 class="text-3xl font-semibold">
        <%= @title %>
      </h1>

      <%= if @opened_for == "show-modal" do %>
        <div class="flex flex-col p-3 items-start bg-gray-100 mt-3 rounded">
          <div class="flex flex-row items-center">
            <p class="rounded-lg bg-blue-planning-300 text-white p-1">DID YOU KNOW?</p>
          </div>
          <p class="text-gray-500 whitespace-pre-wrap mt-1"><%= @subtitle %></p>
        </div>
      <% else %>
        <%= if @subtitle do %>
          <p class="pt-4 whitespace-pre-wrap text-base-250"><%= @subtitle %></p>
        <% end %>
      <% end %>

      <%= if @external_link do %>
        <a class="flex items-center pt-4 text-blue-planning-300 underline font-medium hover:cursor-pointer" href={@url} target="_blank"><%= @external_link %><.icon name="external-link" class="ml-2 w-4 h-4" /></a>
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
  def handle_event(
        "close_event",
        %{},
        %{assigns: %{parent_pid: parent_pid, close_event: close_event}} = socket
      ) do
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

  @spec open(Phoenix.LiveView.Socket.t(), %{
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
          optional(:external_link) => binary,
          optional(:url) => binary,
          optional(:opened_for) => binary,
          title: binary
        }) :: Phoenix.LiveView.Socket.t()
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
