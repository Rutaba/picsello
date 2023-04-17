defmodule PicselloWeb.Shared.ConfirmationComponent do
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
    subtitle: nil,
    dropdown?: false,
    dropdown_label: nil,
    dropdown_values: []
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
      <%= if @icon && !@dropdown? do %>
        <.icon name={@icon} class="mb-2 w-11 h-11" />
      <% end %>

      <h1 class="text-3xl font-bold">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4"><%= raw(@subtitle) %></p>
      <% end %>

      <.section {assigns} />
    </div>
    """
  end

  defp section(%{dropdown?: true} = assigns) do
    ~H"""
    <.form :let={f} for={%{}} as={:dropdown} phx-submit={@confirm_event} phx-target={@myself} class="mt-2">
      <h1 class="font-extrabold text-sm"><%= @dropdown_label %></h1>
      <%= select(f, :item_id, @dropdown_items, class: "w-full px-2 py-3 border border-slate-400 rounded-md mt-1") %>

      <div class="flex justify-end mt-4">
        <button class="w-full md:w-auto btn-secondary text-center mr-2" type="button" phx-click="modal" phx-value-action="close">
          <%= @close_label %>
        </button>

        <button class="w-full md:w-auto btn-primary text-center" phx-disable-with="Saving&hellip;">
          <%= @confirm_label %>
        </button>
      </div>
    </.form>
    """
  end

  defp section(assigns) do
    ~H"""
    <%= if @gallery_name && @gallery_count do %>
      <p class="pt-4">Are you sure you wish to permanently delete
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

        <button class="w-full mt-4 px-6 py-3 font-medium text-base-300 bg-white border border-base-300 rounded-lg hover:bg-base-300/10 focus:outline-none focus:ring-2 focus:ring-base-300/70 focus:ring-opacity-75" type="button" phx-click="modal" phx-value-action="close">
          <%= @close_label %>
        </button>
    """
  end

  @impl true

  def handle_event(
        event,
        %{"dropdown" => %{"item_id" => item_id}},
        %{assigns: %{parent_pid: parent_pid}} = socket
      ) do
    send(parent_pid, {:confirm_event, event, %{item_id: item_id}})

    socket |> noreply()
  end

  def handle_event(event, %{}, %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket) do
    send(parent_pid, {:confirm_event, event, payload})

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
          optional(:dropdown?) => boolean(),
          optional(:dropdown_label) => binary | nil,
          optional(:dropdown_items) => list(),
          title: binary
        }) :: Phoenix.LiveView.Socket.t()
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
