defmodule PicselloWeb.JobLive.New do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.Job

  @impl true
  def mount(_params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("save", _params, socket) do
    socket |> noreply()
  end

  defp assign_changeset(
         %{assigns: %{current_user: current_user}} = socket,
         action \\ nil,
         params \\ %{"client" => %{}}
       ) do
    changeset =
      params
      |> put_in(["client", "organization_id"], current_user.organization_id)
      |> Job.create_changeset()
      |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end
end
