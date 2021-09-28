defmodule PicselloWeb.LiveModal do
  @moduledoc false
  use Phoenix.Component

  defmodule FooterComponent do
    @moduledoc "default footer"
    use PicselloWeb, :live_component

    def update(assigns, socket) do
      socket |> assign(assigns |> Enum.into(%{inner_block: nil, disabled: false})) |> ok()
    end

    def render(assigns) do
      ~L"""
      <div class="pt-40"></div>

      <div id="modal-buttons" class="sticky px-4 -m-4 -bottom-4 sm:px-8 sm:-m-8 sm:-bottom-8">
        <div class="py-6 text-center bg-white">

          <%= if @inner_block do %>
            <%= render_block @inner_block %>
          <% else %>
            <button class="w-32 m-1 btn-primary" title="save" type="submit" <%= if @disabled, do: "disabled" %> phx-disable-with="Saving...">
              Save
            </button>

            <button class="w-32 m-1 btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Cancel
            </button>
          <% end %>
        </div>
      </div>
      """
    end
  end

  def footer(assigns) do
    assigns = Map.put_new(assigns, :disabled, false)

    ~H"""
      <%= live_component PicselloWeb.LiveModal.FooterComponent, disabled: @disabled, inner_block: @inner_block %>
    """
  end

  defmodule Modal do
    @moduledoc "stuff for modals"

    defstruct state: :closed,
              component: nil,
              assigns: %{},
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
          assigns: config |> Map.get(:assigns, %{})
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
    Process.send_after(self(), {:modal, :closed}, modal.transition_ms)

    socket
    |> push_event("modal:close", %{transition_ms: modal.transition_ms})
    |> noreply()
  end

  @impl true
  def handle_info({:modal, :open, component, config}, %{assigns: %{modal: modal}} = socket) do
    Process.send_after(self(), {:modal, :open}, 50)

    socket
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
    ~L"""
    <div role="dialog" id="modal-wrapper" phx-hook="Modal" style="transition-duration: <%= @modal.transition_ms %>ms"
         class="flex items-center justify-center w-full h-full bg-black/20 shadow z-20 fixed transition-opacity ease-in-out
                <%= %{open: "opacity-100 bottom-0 top-0", opening: "opacity-0", closed: "opacity-0 hidden"}[@modal.state] %>">
        <%= if @modal.state != :closed do %>
          <div id="modal-container" class="self-end overflow-hidden rounded-t-lg sm:rounded-b-lg sm:self-auto" phx-hook="LockBodyScroll">
            <%= live_component @modal.component, @modal.assigns |> Map.merge(%{id: @modal.component}) %>
          </div>
        <% end %>
      </div>
    """
  end
end
