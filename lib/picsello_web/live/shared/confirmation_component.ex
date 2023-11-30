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
    dropdown_items: [],
    empty_dropdown_description: "No items available for selection",
    copy_btn_label: nil,
    copy_btn_event: nil,
    copy_btn_value: nil
  }
  @impl true
  def update(
        %{
          payload: %{
            booking_event_date_id: date_id,
            dates_with_slots: dates_with_slots
          }
        } = assigns,
        socket
      ) do
    socket
    |> assign(Enum.into(assigns, @default_assigns))
    |> assign(
      :date_labels,
      dates_with_slots |> Enum.map(fn %{id: id, date: date} -> {date, id} end)
    )
    |> assign(:dropdown_items, get_date_slots(dates_with_slots, date_id))
    |> ok()
  end

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
        <.icon name={@icon} class="mb-4 w-11 h-11" />
      <% end %>

      <h1 class="text-3xl font-bold">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4"><%= raw(@subtitle) %></p>
      <% end %>

      <%= if Map.has_key?(@payload, :client_name) do %>
        <%= if @payload.client_name do %>
          <div class="flex items-center mt-6 mb-8">
            <.icon name={@payload.client_icon} class="mt-2 w-6 h-6 text-blue-planning-300" />
            <p class="text-normal font-semibold ml-3">
              <%= @payload.client_name %>
            </p>
          </div>
        <% end %>
      <% end %>

      <.section {assigns} />
    </div>
    """
  end

  defp section(%{dropdown?: true} = assigns) do
    ~H"""
      <.form :let={f} for={%{}} as={:dropdown} phx-submit={@confirm_event} phx-target={@myself} phx-change="validate" class="mt-2">
        <h1 class="font-extrabold text-sm">Pick a date</h1>
        <%= select(f, :date_id, @date_labels, class: "w-full px-2 py-3 border border-slate-400 rounded-md mt-1 cursor-pointer") %>
        <%= if Enum.any?(@dropdown_items) do %>
          <h1 class="font-extrabold text-sm"><%= @dropdown_label %></h1>
          <%= select(f, :item_id, @dropdown_items, class: "w-full px-2 py-3 border border-slate-400 rounded-md mt-1 cursor-pointer") %>
        <% else %>
          <div>
            <%= @empty_dropdown_description %>
          </div>
        <% end %>

        <button class="w-full btn-primary text-center mt-6" disabled={Enum.empty?(@dropdown_items)} phx-disable-with="Saving&hellip;">
          <%= @confirm_label %>
        </button>

        <button class="w-full btn-secondary text-center mt-4" type="button" phx-click="modal" phx-value-action="close">
          <%= @close_label %>
        </button>
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

      <%= if @copy_btn_label do %>
        <button class="w-full mt-2 px-6 py-3 btn-tertiary text-blue-planning-300" type="button" id="copy-calendar-link" data-clipboard-text={@copy_btn_value} phx-hook="Clipboard">
          <%= @copy_btn_label %>
          <div class="hidden p-1 text-sm rounded shadow bg-white" role="tooltip">
            Copied!
          </div>
        </button>
      <% end %>

      <button class="w-full mt-4 px-6 py-3 font-medium text-base-300 bg-white border border-base-300 rounded-lg hover:bg-base-300/10 focus:outline-none focus:ring-2 focus:ring-base-300/70 focus:ring-opacity-75" type="button" phx-click="modal" phx-value-action="close">
        <%= @close_label %>
      </button>
    """
  end

  def handle_event(
        "validate",
        %{"_target" => ["dropdown", "date_id"], "dropdown" => %{"date_id" => id}},
        %{assigns: %{payload: %{dates_with_slots: dates_with_slots} = payload}} = socket
      ) do
    id = String.to_integer(id)

    socket
    |> assign(:payload, Map.put(payload, :booking_event_date_id, id))
    |> assign(:dropdown_items, get_date_slots(dates_with_slots, id))
    |> noreply()
  end

  @impl true
  def handle_event(
        "reschedule_session",
        %{"dropdown" => %{"date_id" => date_id, "item_id" => item_id}},
        %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket
      ) do
    send(
      parent_pid,
      {:confirm_event, "reschedule_session",
       Map.put(payload, :item_id, item_id) |> Map.put(:booking_event_date_id, date_id)}
    )

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

  defp get_date_slots(dates, date_id),
    do:
      dates
      |> Enum.filter(fn %{id: id} -> id == date_id end)
      |> hd()
      |> Map.get(:slots)

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
