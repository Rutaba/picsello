defmodule Picsello.Workers.CalendarEvent do
  @moduledoc "Background job to clear obsolete files in storage"
  use Oban.Worker, queue: :storage

  alias Picsello.{NylasCalendar, Shoot, Shoots, Repo}
  require Logger

  def perform(%Oban.Job{args: %{"type" => "insert", "shoot_id" => shoot_id}}) do
    shoot = get_shoot(shoot_id)
    {params, token} = map_event(shoot, :insert)

    case NylasCalendar.create_event(params, token) do
      {:ok, %{"id" => id}} ->
        shoot
        |> Shoot.update_changeset(%{external_event_id: id})
        |> Repo.update!()

        Logger.info("Event created for shoot_id #{shoot_id}")

      error ->
        Logger.error("Error #{inspect(error)}")
    end

    :ok
  end

  def perform(%Oban.Job{args: %{"type" => "update", "shoot_id" => shoot_id}}) do
    shoot = get_shoot(shoot_id)

    if shoot.external_event_id do
    {params, token} = map_event(shoot, :update)

    case NylasCalendar.update_event(params, token) do
      {:ok, _event} ->
        Logger.info("Event updated for shoot_id #{shoot_id}")

      error ->
        Logger.error("Error #{inspect(error)}")
    end
  end

    :ok
  end

  def perform(x) do
    Logger.warn("Unknown job format #{inspect(x)}")
    :ok
  end

  defp get_shoot(shoot_id), do: shoot_id |> Shoots.get_shoot() |> Shoots.load_user()

  def map_event(%{job: %{client: %{organization: %{user: user}}}} = shoot, action) do
    nylas_detail = user.nylas_detail

    {Shoot.map_event(shoot, nylas_detail, action), nylas_detail.oauth_token}
  end
end
