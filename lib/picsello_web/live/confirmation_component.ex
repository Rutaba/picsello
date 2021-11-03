defmodule PicselloWeb.ConfirmationComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(
      Enum.into(assigns, %{
        close_label: "Close",
        close_class: "btn-secondary",
        confirm_event: nil,
        confirm_label: "Yes",
        confirm_class: "btn-warning",
        icon: "confetti",
        subtitle: nil
      })
    )
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dialog">
      <.icon name={@icon}, class="w-11 h-11" />

      <h1 class="text-3xl font-semibold">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4"><%= @subtitle %></p>
      <% end %>

      <%= if @confirm_event do %>
        <button class={"w-full mt-6 " <> @confirm_class} title={@confirm_label} type="button" phx-click={@confirm_event} phx-disable-with="Saving&hellip;" phx-target={@myself}>
          <%= @confirm_label %>
        </button>
      <% end %>

      <button class={"w-full mt-6" <> @close_class} type="button" phx-click="modal" phx-value-action="close">
        <%= @close_label %>
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
    send(parent_pid, {:confirm_event, event})

    socket |> noreply()
  end

  @spec open(%Phoenix.LiveView.Socket{}, %{
          optional(:close_label) => binary,
          optional(:close_class) => binary,
          optional(:confirm_event) => any,
          optional(:confirm_label) => binary,
          optional(:confirm_class) => binary,
          optional(:icon) => binary,
          optional(:subtitle) => binary,
          title: binary
        }) :: %Phoenix.LiveView.Socket{}
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
