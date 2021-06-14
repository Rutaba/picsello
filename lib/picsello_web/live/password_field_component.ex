defmodule PicselloWeb.PasswordFieldComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, hide_password: true)}
  end

  @impl true
  def handle_event("toggle-password", %{}, socket) do
    {:noreply, assign(socket, hide_password: !socket.assigns.hide_password)}
  end
end
