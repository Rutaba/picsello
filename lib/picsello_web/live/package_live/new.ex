defmodule PicselloWeb.PackageLive.New do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo, Package}

  @impl true
  def mount(%{"job_id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_job(job_id)
    |> maybe_redirect()
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"package" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"package" => params}, %{assigns: %{job: job}} = socket) do
    changeset = build_changeset(socket, params)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:package, changeset)
      |> Ecto.Multi.merge(fn %{package: %{id: package_id}} ->
        Ecto.Multi.new()
        |> Ecto.Multi.update(
          :job,
          Job.add_package_changeset(job, %{package_id: package_id})
        )
      end)
      |> Repo.transaction()

    case result do
      {:ok, _} ->
        socket |> push_redirect(to: Routes.job_path(socket, :show, job.id)) |> noreply()

      {:error, :package, changeset, _} ->
        socket |> assign(changeset: changeset) |> noreply()

      {:error, :job, _changeset, _} ->
        socket |> put_flash(:error, "Oops! Something went wrong. Please try again.") |> noreply()
    end
  end

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job = current_user |> Job.for_user() |> Repo.get!(job_id) |> Repo.preload(:client)

    socket |> assign(:job, job)
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user}},
         params
       ) do
    params
    |> Map.put("organization_id", current_user.organization_id)
    |> Package.create_changeset()
  end

  defp assign_changeset(
         socket,
         action \\ nil,
         params \\ %{}
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp maybe_redirect(%{assigns: %{job: %{id: job_id, package_id: package_id}}} = socket)
       when package_id != nil do
    socket |> push_redirect(to: Routes.job_path(socket, :show, job_id))
  end

  defp maybe_redirect(socket), do: socket
end
