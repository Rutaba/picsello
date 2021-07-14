defmodule PicselloWeb.Modal do
  @moduledoc "stuff for modals"

  defstruct state: :closed, component: nil, assigns: %{}

  def new(), do: %__MODULE__{}

  def close(%__MODULE__{} = modal), do: %{modal | component: nil, state: :closed}

  def closing(%__MODULE__{} = modal), do: %{modal | state: :closing}

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

    def close_modal(%{assigns: %{modal: modal}} = socket, wait_ms \\ 500) do
      Process.send_after(self(), {:modal, :close}, wait_ms)

      socket |> assign(modal: modal |> Modal.closing())
    end
  end

  defmodule ComponentHelpers do
    @moduledoc "for use in modal live components"

    def close_modal(wait_ms \\ 500), do: send(self(), {:modal, :animate_close, wait_ms})
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
            |> close_modal(params |> Map.get("wait-ms", "500") |> String.to_integer())
            |> noreply()

      @impl true
      def handle_info({:modal, :animate_close, ms}, %{assigns: %{modal: modal}} = socket),
        do: socket |> close_modal(ms) |> noreply()

      @impl true
      def handle_info({:modal, :close}, %{assigns: %{modal: modal}} = socket),
        do: socket |> assign(modal: modal |> Modal.close()) |> noreply()

      @impl true
      def handle_info({:modal, :open}, %{assigns: %{modal: modal}} = socket),
        do: socket |> assign(modal: %{modal | state: :open}) |> noreply()
    end
  end
end
