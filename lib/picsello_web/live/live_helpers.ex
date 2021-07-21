defmodule PicselloWeb.LiveHelpers do
  @moduledoc "used in both views and components"

  def open_modal(socket, component, assigns \\ %{}) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "modal:#{inspect(socket.root_pid)}",
      {:modal, :open, component, assigns}
    )

    socket
  end

  def close_modal(socket) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "modal:#{inspect(socket.root_pid)}",
      {:modal, :close}
    )

    socket
  end

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}
end
