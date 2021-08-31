defmodule PicselloWeb.LiveHelpers do
  @moduledoc "used in both views and components"

  import Phoenix.LiveView, only: [assign: 2]

  def open_modal(socket, component, assigns \\ %{})

  # main process, modal pid is assigned
  def open_modal(
        %{assigns: %{modal_pid: modal_pid} = parent_assigns} = socket,
        component,
        %{assigns: assigns} = config
      )
      when is_pid(modal_pid) do
    send(
      modal_pid,
      {:modal, :open, component,
       config
       |> Map.put(
         :assigns,
         assigns
         |> Map.merge(Map.take(parent_assigns, [:live_action]))
       )}
    )

    socket
  end

  # called with raw assigns map
  def open_modal(
        %{assigns: %{modal_pid: modal_pid}} = socket,
        component,
        assigns
      )
      when is_pid(modal_pid),
      do: socket |> open_modal(component, %{assigns: assigns})

  # modal process
  def open_modal(
        %{view: PicselloWeb.LiveModal} = socket,
        component,
        config
      ),
      do: socket |> assign(modal_pid: self()) |> open_modal(component, config)

  # main process, before modal pid is assigned
  def open_modal(
        socket,
        component,
        config
      ) do
    socket
    |> assign(queued_modal: {component, config})
  end

  # close from main process
  def close_modal(%{assigns: %{modal_pid: modal_pid}} = socket) do
    send(modal_pid, {:modal, :close})

    socket
  end

  # close from within modal process
  def close_modal(socket) do
    send(self(), {:modal, :close})

    socket
  end

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}
end
