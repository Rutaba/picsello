defmodule PicselloWeb.LiveHelpers do
  @moduledoc "used in both views and components"

  def open_modal(
        %{assigns: %{modal_pid: modal_pid} = parent_assigns} = socket,
        component,
        assigns
      ) do
    send(
      modal_pid,
      {:modal, :open, component, assigns |> Map.merge(Map.take(parent_assigns, [:live_action]))}
    )

    socket
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

  def modal_topic(socket), do: "modal:#{inspect(socket.root_pid)}"
end
