defmodule PicselloWeb.LiveModal do
  @moduledoc false

  defmodule Modal do
    @moduledoc "stuff for modals"

    defstruct state: :closed,
              component: nil,
              closable: true,
              assigns: %{},
              close_event: nil,
              transition_ms: 0

    def new() do
      transition_ms = Application.get_env(:picsello, :modal_transition_ms)
      %__MODULE__{transition_ms: transition_ms}
    end

    def open(%__MODULE__{} = modal, component, config),
      do: %{
        modal
        | component: component,
          state: :opening,
          assigns: Map.get(config, :assigns, %{}),
          close_event: Map.get(config, :close_event),
          closable: Map.get(config, :closable, true)
      }
  end

  use PicselloWeb, :live_view

  alias PicselloWeb.LiveModal.Modal

  @impl true
  def mount(_params, session, socket) do
    if(connected?(socket), do: send(socket.root_pid, {:modal_pid, self()}))

    socket |> assign_defaults(session) |> assign(modal: Modal.new()) |> ok()
  end

  @impl true
  def handle_event("modal", %{"action" => "close"}, socket),
    do: handle_info({:modal, :close}, socket)

  @impl true
  def handle_info({:modal, :close}, %{assigns: %{modal: modal}} = socket) do
    if modal.close_event, do: send(socket.root_pid, {modal.close_event, modal})
    Process.send_after(self(), {:modal, :closed}, modal.transition_ms)

    socket
    |> push_event("modal:close", %{transition_ms: modal.transition_ms})
    |> noreply()
  end

  @impl true
  def handle_info({:modal, :open, component, config}, %{assigns: %{modal: modal}} = socket) do
    Process.send_after(self(), {:modal, :open}, 50)

    socket
    |> push_event("modal:open", %{transition_ms: modal.transition_ms})
    |> assign(modal: modal |> Modal.open(component, config))
    |> noreply()
  end

  @impl true
  def handle_info({:modal, state}, %{assigns: %{modal: modal}} = socket),
    do: socket |> assign(modal: %{modal | state: state}) |> noreply()

  @impl true
  def handle_info(other, %{parent_pid: parent_pid} = socket) do
    send(parent_pid, other)
    socket |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div role="dialog" id="modal-wrapper" data-closable={@modal.closable} phx-hook="Modal" style={"transition-duration: #{@modal.transition_ms}ms"} class={classes(["flex items-center justify-center w-full h-full bg-base-300/90 z-50 fixed transition-opacity ease-in-out", %{open: "opacity-100 bottom-0 top-0", opening: "opacity-0", closed: "opacity-0 hidden"}[@modal.state]])}>
      <%= if @modal.state != :closed do %>
        <div class="modal-container">
          <%= live_component @modal.component, @modal.assigns |> Map.merge(%{id: @modal.component}) %>
        </div>
      <% end %>
    </div>
    """
  end

  def footer(assigns) do
    assigns =
      Enum.into(assigns, %{
        disabled: false,
        inner_block: nil,
        class: "pt-40"
      })

    ~H"""
      <div class={@class}></div>

      <div {testid("modal-buttons")} class="sticky px-4 -m-4 bg-white -bottom-6 sm:px-8 sm:-m-8 sm:-bottom-8">
        <div class="flex flex-col py-6 bg-white gap-2 sm:flex-row-reverse">
          <%= if @inner_block do %>
            <%= render_block @inner_block %>
          <% else %>
            <button class="btn-primary" title="save" type="submit" disabled={@disabled} phx-disable-with="Save">
              Save
            </button>

            <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Cancel
            </button>
          <% end %>
        </div>
      </div>
    """
  end

  def close_x(assigns) do
    assigns = Enum.into(assigns, %{close_event: nil, phx_value_link: nil})

    ~H"""
    <%= if @close_event do %>
      <button phx-click="close_event" phx-value-action={@close_event} phx-value-link={@phx_value_link} phx-target={@myself} type="button" title="cancel" class="absolute p-2 top-3 right-3 sm:top-6 sm:right-6">
        <.icon name="close-x" class="w-6 h-6 stroke-current" />
      </button>
    <% else %>
      <button phx-click="modal" phx-value-action="close" type="button" title="cancel" class="absolute p-2 top-3 right-3 sm:top-6 sm:right-6">
        <.icon name="close-x" class="w-6 h-6 stroke-current" />
      </button>
    <% end %>
    """
  end
end
