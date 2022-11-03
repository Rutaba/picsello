defmodule PicselloWeb.SuccessComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  @default_assigns %{
    close_label: "Close",
    close_class: "border border-current p-3 rounded-lg font-semibold text-lg",
    success_event: nil,
    success_label: "Go to item",
    success_class: "btn-primary font-semibold text-lg",
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
    assigns = Enum.into(assigns, %{class: "bg-white p-6 rounded-lg"})

    ~H"""
    <div class={@class <> " max-w-[642px]"}>

      <h1 class="font-bold text-3xl">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4 whitespace-pre-wrap font-medium text-lg"><%= @subtitle %></p>
      <% end %>

      <div style="border-radius: 10px" class="flex flex-col px-6 pt-6 mt-4 bg-neutral-200 text-lg">
        <div class="mb-4">
          <.description />
        </div>
        <div class="grid grid-cols-4">
          <.inner_section />
        </div>
      </div>

      <%= if @success_event do %>
        <button class={"w-full mt-6 " <> @success_class} title={@success_label} type="button" phx-click={@success_event} phx-disable-with="Saving&hellip;" phx-target={@myself}>
          <%= @success_label %>
        </button>
      <% end %>

      <button class={"w-full mt-6 " <> @close_class} type="button" phx-click="modal" phx-value-action="close">
        <%= @close_label %>
      </button>
    </div>
    """
  end

  @impl true
  def handle_event(event, %{}, %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket) do
    send(parent_pid, {:success_event, event, payload})

    socket |> noreply()
  end

  @impl true
  def handle_event(event, %{}, %{assigns: %{parent_pid: parent_pid}} = socket) do
    send(parent_pid, {:success_event, event})

    socket |> noreply()
  end

  @spec open(%Phoenix.LiveView.Socket{}, %{
          optional(:close_label) => binary,
          optional(:close_class) => binary,
          optional(:success_event) => any,
          optional(:success_label) => binary,
          optional(:success_class) => binary,
          optional(:class) => binary | nil,
          optional(:subtitle) => binary,
          optional(:payload) => map,
          title: binary
        }) :: %Phoenix.LiveView.Socket{}
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end

  defp description(assigns) do
    ~H"""
      <span class="font-bold">We've created a client and a job under the hood for you.</span> A job is the hub for your gallery,
      transaction history, and communication with your client. Don't forget you can
      use Picsello to handle everything!
    """
  end

  defp inner_section(assigns) do
    ~H"""
    <div class="flex justify-center items-center">
    <.icon name="rupees" class="w-8 h-8"/>
    </div>
    <div class="col-span-2 row-span-2">
      <img src="images/gallery_created.png" />
    </div>
    <div class="flex justify-center items-center">
      <.icon name="phone" style="color: rgba(137, 137, 137, 0.2)" class="w-8 h-8"/>
    </div>
    <div class="flex justify-center items-center pb-6">
      <.icon name="cart" style="color: rgba(137, 137, 137, 0.2)" class="w-8 h-8"/>
    </div>
    <div class="flex justify-center items-center pb-6">
      <.icon name="envelope" style="color: rgba(137, 137, 137, 0.2)" class="w-8 h-8"/>
    </div>
    """
  end
end
