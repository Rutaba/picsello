defmodule PicselloWeb.ShootLive.NewComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Shoot, Job, Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset(%{}, nil)
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"shoot" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"shoot" => params},
        %{assigns: %{shoot_number: shoot_number}} = socket
      ) do
    case socket |> build_changeset(params) |> Repo.insert() do
      {:ok, shoot} ->
        close_modal(%{shoot: shoot})

        send_update(PicselloWeb.JobLive.ShootDetailsComponent,
          id: shoot_number,
          shoot: shoot
        )

        socket |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(%{assigns: %{job: %{id: job_id}}}, params) do
    params
    |> Map.put("job_id", job_id)
    |> Shoot.create_changeset()
  end

  defp assign_changeset(
         socket,
         params,
         action
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end
end
