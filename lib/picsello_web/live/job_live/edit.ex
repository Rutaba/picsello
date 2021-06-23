defmodule PicselloWeb.JobLive.Edit do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo}

  @impl true
  def mount(%{"id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_job(job_id)
    |> assign_changeset()
    |> maybe_redirect()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"job" => params}, socket) do
    changeset = build_changeset(socket, params)

    case changeset |> Repo.update() do
      {:ok, %Job{id: job_id}} ->
        socket
        |> put_flash(:info, "Job updated successfully.")
        |> push_redirect(to: Routes.job_path(socket, :show, job_id))
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job = current_user |> Job.for_user() |> Repo.get!(job_id) |> Repo.preload([:client, :package])

    socket |> assign(:job, job)
  end

  defp maybe_redirect(%{assigns: %{job: %{id: job_id, package_id: nil}}} = socket) do
    socket |> push_redirect(to: Routes.job_package_path(socket, :new, job_id))
  end

  defp maybe_redirect(socket), do: socket

  defp assign_changeset(
         socket,
         action \\ nil,
         params \\ %{}
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp build_changeset(%{assigns: %{job: job}}, params) do
    job
    |> Job.update_changeset(params)
  end
end
