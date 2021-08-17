defmodule PicselloWeb.LiveHelpers do
  @moduledoc "used in both views and components"

  import Phoenix.LiveView, only: [assign: 2]

  def open_modal(socket, component, assigns \\ %{})

  def open_modal(
        %{assigns: %{modal_pid: modal_pid} = parent_assigns} = socket,
        component,
        assigns
      )
      when is_pid(modal_pid) do
    send(
      modal_pid,
      {:modal, :open, component, assigns |> Map.merge(Map.take(parent_assigns, [:live_action]))}
    )

    socket
  end

  def open_modal(
        socket,
        component,
        assigns
      ) do
    socket |> assign(queued_modal: {component, assigns})
  end

  def close_modal(%{assigns: %{modal_pid: modal_pid}} = socket) do
    send(modal_pid, {:modal, :close})

    socket
  end

  def close_modal(socket) do
    send(self(), {:modal, :close})

    socket
  end

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}
end
