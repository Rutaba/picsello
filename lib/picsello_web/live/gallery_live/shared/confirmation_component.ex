defmodule PicselloWeb.GalleryLive.Shared.ConfirmationComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  @default_assigns %{
    close_label: "Close",
    close_class: "btn-secondary",
    confirm_event: nil,
    confirm_label: "Yes",
    confirm_class: "btn-warning",
    icon: "confetti",
    gallery_name: nil,
    gallery_count: nil,
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
    class = Map.get(assigns, :class, "dialog")
    ~H"""
    <div class={"" <> class}>
      <%= if @icon do %>
        <.icon name={@icon} class="mb-2 w-11 h-11" />
      <% end %>

      <h1 class="text-3xl font-bold">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4"><%= @subtitle %></p>
      <% end %>

      <%= if @gallery_name && @gallery_count do %>
        <p class="pt-4 font-sans">Are you sure you wish to permanently delete
        <span class="font-bold"><%= @gallery_name %></span>
        gallery, and the
        <span class="font-bold"><%= @gallery_count %> photos</span>
        it contains?</p>
      <% end %>

      <%= if @confirm_event do %>
        <button class={"w-full mt-6 " <> @confirm_class} title={@confirm_label} type="button" phx-click={@confirm_event} phx-disable-with="Saving&hellip;" phx-target={@myself}>
          <%= @confirm_label %>
        </button>
      <% end %>

      <button class={"w-full mt-4 " <> @close_class} type="button" phx-click="modal" phx-value-action="close">
        <%= @close_label %>
      </button>
    </div>
    """
  end

  @impl true
  def handle_event(event, %{}, %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket) do
    send(parent_pid, {:confirm_event, event, payload})

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
          optional(:class) => binary,
          optional(:confirm_event) => any,
          optional(:confirm_label) => binary,
          optional(:confirm_class) => binary,
          optional(:icon) => binary | nil,
          optional(:title) => binary,
          optional(:subtitle) => binary,
          optional(:gallery_name) => binary,
          optional(:gallery_count) => binary,
          optional(:payload) => map,
          title: binary
        }) :: %Phoenix.LiveView.Socket{}
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
