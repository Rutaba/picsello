defmodule PicselloWeb.GalleryLive.Pricing.ConfirmationComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  import PicselloWeb.GalleryLive.Pricing.Index, only: [grid_item: 1, get_pricing_value: 1]

  @default_assigns %{
    close_label: "Close",
    close_class: "btn-secondary",
    confirm_event: nil,
    close_event: nil,
    confirm_label: "Yes, reset",
    confirm_class: "btn-warning",
    icon: "no-icon",
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
        You're resetting this gallery's pricing
      </h1>
      <p class="pt-4 whitespace-pre-wrap text-base-250">Here's what you have set in the package:</p>

      <div class="flex flex-col mt-2">
        <.grid_item icon="money-bags" item_name="Print Credits" item_value={get_pricing_value(@gallery).print_credits || "-"} />
        <.grid_item icon="money-bags" item_name="Digital Image Price" item_value={get_pricing_value(@gallery).download_each_price || "-"} />
        <.grid_item icon="photos-2" item_name="Included Digital Images" item_value={get_pricing_value(@gallery).download_count || "-"} />
        <.grid_item icon="money-bags" item_name="Buy Them All Price" item_value={get_pricing_value(@gallery).buy_all || "-"} />

      </div>

      <button class={"w-full mt-8 " <> @confirm_class} title="Yes, reset" type="button" phx-click="reset-digital-pricing" phx-disable-with="Saving&hellip;" phx-target={@myself}>
        Yes, reset
      </button>

      <button class={"w-full mt-6 " <> @close_class} type="button" phx-click="modal" phx-value-action="close">
        Cancel
      </button>

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
