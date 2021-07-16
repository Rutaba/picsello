defmodule PicselloWeb.Modal do
  @moduledoc "stuff for modals"

  defstruct state: :closed, component: nil, assigns: %{}, transition_ms: 0

  def new() do
    transition_ms = if Mix.env() == :test, do: 0, else: 400
    %__MODULE__{transition_ms: transition_ms}
  end

  def close(%__MODULE__{} = modal), do: %{modal | state: :closed}

  def closing(%__MODULE__{assigns: assigns} = modal, new_assigns),
    do: %{modal | state: :closing, assigns: Map.merge(assigns, new_assigns)}

  def open(%__MODULE__{} = modal, component, assigns),
    do: %{modal | component: component, state: :opening, assigns: assigns}

  defmodule ViewHelpers do
    @moduledoc "for use in live views"

    alias PicselloWeb.Modal
    import Phoenix.LiveView, only: [assign: 2]

    def open_modal(%{assigns: %{modal: modal}} = socket, component, assigns \\ %{}) do
      Process.send_after(self(), {:modal, :open}, 50)

      socket
      |> assign(modal: modal |> Modal.open(component, assigns))
    end

    def close_modal(%{assigns: %{modal: modal}} = socket, assigns \\ %{}) do
      Process.send_after(self(), {:modal, :close}, modal.transition_ms)

      socket
      |> assign(modal: modal |> Modal.closing(assigns))
    end
  end

  defmodule ComponentHelpers do
    @moduledoc "for use in modal live components"

    def close_modal(assigns \\ %{}), do: send(self(), {:modal, :animate_close, assigns})

    def open_modal(component, assigns),
      do: send(self(), {:modal, :animate_open, component, assigns})
  end

  def live_view_handlers do
    quote do
      alias PicselloWeb.Modal
      import PicselloWeb.Modal.ViewHelpers

      @impl true
      def handle_event(
            "modal",
            %{"action" => "close"} = params,
            %{assigns: %{modal: modal}} = socket
          ),
          do:
            socket
            |> close_modal()
            |> noreply()

      @impl true
      def handle_info({:modal, :animate_close, assigns}, socket),
        do: socket |> close_modal(assigns) |> noreply()

      @impl true
      def handle_info({:modal, :animate_open, component, assigns}, socket),
        do: socket |> open_modal(component, assigns) |> noreply()

      @impl true
      def handle_info({:modal, :close}, %{assigns: %{modal: modal}} = socket),
        do: socket |> assign(modal: modal |> Modal.close()) |> noreply()

      @impl true
      def handle_info({:modal, :open}, %{assigns: %{modal: modal}} = socket),
        do: socket |> assign(modal: %{modal | state: :open}) |> noreply()
    end
  end
end
