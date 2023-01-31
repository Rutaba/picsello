defmodule PicselloWeb.PackageLive.ConfirmationComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  @default_assigns %{
    close_label: "Close",
    close_class: "btn-secondary",
    confirm_event: nil,
    checkbox_event1: nil,
    checked: nil,
    checked2: nil,
    close_event: nil,
    confirm_label: "Yes",
    confirm_class: "btn-warning",
    icon: "confetti",
    subtitle: nil,
    subtitle2: nil,
    heading: nil,
    heading2: nil
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
          <div class="flex items-center">
            <div class="flex items-center justify-center w-6 h-6 mr-3 mb-1 rounded-full flex-shrink-0 text-white bg-blue-planning-300">
              <.icon name={@icon} class="fill-current" width="14" height="14" />
            </div>
            <span class="flex capitalize font-semibold"><%= @icon %></span>
          </div>
        <% end %>

        <h1 class="text-3xl font-semibold">
          <%= @title %>
        </h1>

        <.section {assigns} />
      </div>
    """
  end

  defp section(assigns) do
    ~H"""
      <.form let={f} for={:check} phx-submit={@confirm_event} phx-target={@myself}>
        <%= if @subtitle && @heading do %>
          <div class="flex flex-col pt-4 items-start">
            <div class="flex flex-row items-center">
              <%= checkbox(f, :check_enabled, class: "w-5 h-5 mr-2 checkbox", checked: @checked, phx_click: @checkbox_event1, phx_target: @myself) %>
              <h1 class="font-bold ml-1">
                <%= @heading %>
              </h1>
            </div>
            <p class="whitespace-pre-wrap"><%= @subtitle %></p>
          </div>
          <hr class="my-4" />
        <% else %>
          <p class="pt-4 whitespace-pre-wrap"><%= @subtitle %></p>
        <% end %>

        <%= if @subtitle2 && @heading2 do %>
          <div class={classes("flex flex-col pt-4 items-start", %{"text-gray-300" => !@checked})}>
            <div class="flex flex-row items-center">
              <%= checkbox(f, :check_profile, class: "w-5 h-5 mr-2 checkbox", checked: @checked2, disabled: !@checked) %>
              <h1 class="font-bold ml-1">
                <%= @heading2 %>
              </h1>
            </div>
            <p class="whitespace-pre-wrap"><%= @subtitle2 %></p>
          </div>
        <% else %>
          <p class="pt-4 whitespace-pre-wrap"><%= @subtitle2 %></p>
        <% end %>

        <%= if @confirm_event do %>
          <button class={"w-full mt-6 " <> @confirm_class} title={@confirm_label} type="submit" phx-disable-with="Saving&hellip;">
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
      </.form>
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
  def handle_event(
        "visibility_for_business",
        %{"value" => value} = params,
        %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket
      ) do
    if !value, do: send(parent_pid, {:confirm_event, "visibility_for_business", payload, params})

    socket
    |> assign(:checked, value)
    |> noreply()
  end

  @impl true
  def handle_event(
        event,
        params,
        %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket
      ) do
    send(parent_pid, {:confirm_event, event, payload, params})

    socket |> noreply()
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
          optional(:confirm_event) => any,
          optional(:close_event) => any,
          optional(:checkbox_event1) => binary,
          optional(:checkbox_event2) => binary,
          optional(:checked) => boolean,
          optional(:checked2) => boolean,
          optional(:confirm_label) => binary,
          optional(:confirm_class) => binary,
          optional(:class) => binary | nil,
          optional(:icon) => binary | nil,
          optional(:subtitle) => binary,
          optional(:subtitle2) => binary,
          optional(:heading) => binary,
          optional(:heading2) => binary,
          optional(:payload) => map,
          title: binary
        }) :: %Phoenix.LiveView.Socket{}
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
