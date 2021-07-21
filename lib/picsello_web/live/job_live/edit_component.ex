defmodule PicselloWeb.JobLive.EditComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Job, Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"job" => params}, socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, job} ->
        send(self(), {:update, job: job})

        close_modal(socket)

        socket |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(%{assigns: %{job: job}}, params) do
    job
    |> Job.update_changeset(params)
  end

  defp assign_changeset(socket, action \\ nil, params \\ %{}) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end
end
