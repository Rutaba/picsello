defmodule PicselloWeb.JobLive.New do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo}

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
  def handle_event("save", %{"job" => params}, socket) do
    changeset = build_changeset(socket, params)

    case changeset |> Repo.insert() do
      {:ok, %Job{id: job_id}} ->
        socket |> push_redirect(to: Routes.job_package_path(socket, :new, job_id)) |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user}},
         params
       ) do
    params
    |> put_in(["client", "organization_id"], current_user.organization_id)
    |> Job.create_changeset()
  end

  defp assign_changeset(
         socket,
         action \\ nil,
         params \\ %{"client" => %{}}
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end
end
