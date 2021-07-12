defmodule PicselloWeb.PasswordFieldComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def mount(socket), do: socket |> assign(hide_password: true) |> ok()

  @impl true
  def update(assigns, socket),
    do: socket |> assign(assigns |> Enum.into(%{label: "Password", name: :password})) |> ok()

  @impl true
  def handle_event("toggle-password", %{}, %{assigns: %{hide_password: hide_password}} = socket),
    do: socket |> assign(hide_password: !hide_password) |> noreply()
end
