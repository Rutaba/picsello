defmodule PicselloWeb.LiveModal do
  @moduledoc false

  defmodule FooterComponent do
    @moduledoc "default footer"
    use PicselloWeb, :live_component

    def render(assigns) do
      ~L"""
      <div class="text-center">
        <button class="w-32 mx-1 btn-primary" type="submit" <%= if @disabled, do: "disabled" %> phx-disable-with="Saving...">
            Save
          </button>

          <button class="w-32 mx-1 btn-secondary" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </div>
      """
    end
  end

  defmodule Modal do
    @moduledoc "stuff for modals"

    @default_footer FooterComponent

    defstruct state: :closed,
              component: nil,
              after_close: false,
              assigns: %{},
              transition_ms: 0,
              show_x: true,
              footer: @default_footer

    def new() do
      transition_ms = Application.get_env(:picsello, :modal_transition_ms)
      %__MODULE__{transition_ms: transition_ms}
    end

    def open(%__MODULE__{} = modal, component, config),
      do: %{
        modal
        | component: component,
          state: :opening,
          assigns: config |> Map.get(:assigns, %{}),
          show_x: config |> Map.get(:show_x, true),
          after_close: config |> Map.get(:after_close, false),
          footer: config |> Map.get(:footer, @default_footer)
      }
  end

  use PicselloWeb, :live_view

  alias PicselloWeb.LiveModal.Modal

  @impl true
  def mount(_params, session, socket) do
    if(connected?(socket), do: send(socket.root_pid, {:modal_pid, self()}))

    socket |> assign_defaults(session) |> assign(modal: Modal.new(), show_x: true) |> ok()
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
  def handle_info(
        {:modal, :closed},
        %{assigns: %{modal: %{after_close: true} = modal}} = socket
      ) do
    Process.send_after(self(), {:modal, :after_close}, 50)
    socket |> assign(modal: %{modal | state: :closed}) |> noreply()
  end

  @impl true
  def handle_info(
        {:modal, :after_close},
        %{assigns: %{modal: %{component: component}}} = socket
      ) do
    send(socket.parent_pid, {:modal, component, :after_close})
    socket |> noreply()
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
      <div role="dialog" id="modal-wraper" phx-hook="Modal" style="transition-duration: <%= @modal.transition_ms %>ms" class="w-full h-full bg-white shadow z-20 fixed transition-top ease-in-out <%= %{open: "bottom-0 top-0", opening: "top-full", closed: "top-full hidden"}[@modal.state] %>">
        <%= if @modal.state != :closed do %>
          <div id="modal" class="h-full overflow-scroll" phx-hook="LockBodyScroll">
            <%= if @modal.show_x do %>
              <div class="flex flex-col w-full pt-7">
                <button phx-click="modal" phx-value-action="close" type="button" title="cancel" class="self-end mr-4 w-7">
                  <%= icon_tag(@socket, "close-modal", class: "h-7 w-7 stroke-current") %>
                </button>
              </div>
            <% end %>
            <%= live_component @modal.component, @modal.assigns |> Map.put(:id, @modal.component) do %>
              <div class="mt-40"></div>

              <div id="modal-buttons" class="left-0 right-0 px-10 bg-white py-7 shadow <%= if(@modal.state == :open, do: "fixed bottom-0", else: "hidden") %>">
                <%= live_component @modal.footer, assigns %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    """
  end
end
