defmodule PicselloWeb.Modal do
  @moduledoc "stuff for modals"

  defstruct state: :closed, component: nil, assigns: %{}

  def new(), do: %__MODULE__{}

  def close(%__MODULE__{} = modal), do: %{modal | component: nil, state: :closed}

  def closing(%__MODULE__{} = modal), do: %{modal | state: :closing}

  def open(%__MODULE__{} = modal, component, assigns),
    do: %{modal | component: component, state: :opening, assigns: assigns}

  defmodule Helpers do
    @moduledoc "for use in liveviews"

    alias PicselloWeb.Modal
    import Phoenix.LiveView, only: [assign: 2]

    def open_modal(%{assigns: %{modal: modal}} = socket, component, assigns \\ %{}) do
      Process.send_after(self(), {:modal, :open}, 50)

      socket
      |> assign(modal: modal |> Modal.open(component, assigns))
    end
  end

  def live_view_handlers do
    quote do
      alias PicselloWeb.Modal
      import PicselloWeb.Modal.Helpers

      @impl true
      def handle_event(
            "modal",
            %{"action" => "close", "wait-ms" => wait_ms},
            %{assigns: %{modal: modal}} = socket
          ) do
        Process.send_after(self(), {:modal, :close}, wait_ms |> String.to_integer())

        socket |> assign(modal: modal |> Modal.closing()) |> noreply()
      end

      @impl true
      def handle_info({:modal, :close}, %{assigns: %{modal: modal}} = socket),
        do: socket |> assign(modal: modal |> Modal.close()) |> noreply()

      @impl true
      def handle_info({:modal, :open}, %{assigns: %{modal: modal}} = socket),
        do: socket |> assign(modal: %{modal | state: :open}) |> noreply()
    end
  end
end
