defmodule PicselloWeb.Live.Profile.Shared do
  @moduledoc """
  functions used by editing profile components
  """
  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  use Phoenix.Component
  alias Picsello.Profiles

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_organization()
    |> assign_changeset()
    |> ok()
  end

  def handle_event("validate", %{"organization" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  def handle_event(
        "save",
        %{"organization" => params},
        %{assigns: %{organization: organization}} = socket
      ) do
    case Profiles.update_organization_profile(organization, params) do
      {:ok, organization} ->
        send(socket.parent_pid, {:update, organization})
        socket |> close_modal() |> noreply()

      {:error, _} ->
        socket |> noreply()
    end
  end

  def open(%{assigns: assigns} = socket, module),
    do:
      open_modal(
        socket,
        module,
        %{
          assigns: Map.take(assigns, [:current_user])
        }
      )

  def assign_changeset(
        %{assigns: %{organization: organization}} = socket,
        params \\ %{},
        action \\ :validate
      ) do
    changeset =
      organization
      |> Profiles.edit_organization_profile_changeset(params)
      |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  def assign_organization(%{assigns: %{current_user: current_user}} = socket) do
    organization = Profiles.find_organization_by(user: current_user)
    socket |> assign(:organization, organization)
  end
end
