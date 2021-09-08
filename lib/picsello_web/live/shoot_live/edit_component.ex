defmodule PicselloWeb.ShootLive.EditComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Shoot, Repo, Job}

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
    case socket |> build_changeset(params) |> upsert do
      {:ok, shoot} ->
        send(self(), {:update, %{shoot_number: shoot_number, shoot: shoot}})

        socket |> assign(shoot: shoot) |> close_modal() |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(
         %{assigns: %{current_user: %{time_zone: time_zone}}} = socket,
         %{"starts_at" => "" <> starts_at} = params
       ) do
    socket
    |> build_changeset(
      params
      |> Map.put(
        "starts_at",
        parse_in_zone(starts_at, time_zone)
      )
    )
  end

  defp build_changeset(%{assigns: %{shoot: shoot}}, params) when shoot != nil do
    shoot |> Shoot.update_changeset(params)
  end

  defp build_changeset(%{assigns: %{job: %{id: job_id}}}, params) do
    params
    |> Map.put("job_id", job_id)
    |> Shoot.create_changeset()
  end

  defp upsert(changeset) do
    case changeset |> Ecto.Changeset.get_field(:id) do
      nil -> changeset |> Repo.insert()
      _ -> changeset |> Repo.update()
    end
  end

  defp assign_changeset(
         socket,
         params,
         action
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end

  defp parse_in_zone("" <> str, zone) do
    with {:ok, naive_datetime} <- NaiveDateTime.from_iso8601(str <> ":00"),
         {:ok, datetime} <- DateTime.from_naive(naive_datetime, zone) do
      datetime
    end
  end
end
