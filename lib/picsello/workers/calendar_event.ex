defmodule Picsello.Workers.CalendarEvent do
  @moduledoc "Background job to move events from previous calendar to new"
  use Oban.Worker, queue: :storage

  alias Picsello.{NylasCalendar, NylasDetails, Accounts, Shoot, Shoots, Repo}
  alias Phoenix.PubSub
  require Logger

  def perform(%Oban.Job{args: %{"type" => "insert", "shoot_id" => shoot_id}}) do
    shoot_id |> get_shoot() |> create_event()

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

  def perform(%Oban.Job{args: %{"type" => "move", "user_id" => user_id}}) do
    user = user_id |> Accounts.get_user!() |> Repo.preload(:nylas_detail)

    user
    |> Shoots.get_by_user_query()
    |> Shoots.has_external_event_query()
    |> Repo.all()
    |> Shoots.load_user()
    |> then(fn shoots ->
      task = Task.async(fn -> delete_events(shoots, user.nylas_detail) end)

      shoots
      |> Task.async_stream(&create_event(&1))
      |> Stream.run()

      Task.await(task)
    end)

    user.nylas_detail |> NylasDetails.reset_event_status!() |> broadcast()

    :ok
  end

  def perform(x) do
    Logger.warning("Unknown job format #{inspect(x)}")
    :ok
  end

  defp delete_events(shoots, nylas_detail) do
    shoots
    |> Task.async_stream(
      fn %{external_event_id: event_id} = shoot ->
        {NylasCalendar.delete_event(event_id, nylas_detail.previous_oauth_token), shoot}
      end,
      timeout: 10_000
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {{:ok, _}, shoot}}, {pass, fail} ->
        {[shoot.external_event_id | pass], fail}

      {:ok, {_, shoot}}, {pass, fail} ->
        {pass, [shoot.external_event_id | fail]}
    end)
    |> then(fn {pass, fail} ->
      Logger.info("Delete: Successfull events #{inspect(pass)}")
      Logger.error("Delete: Failed events #{inspect(fail)}")
    end)
  end

  defp create_event(shoot) do
    {params, token} = map_event(shoot, :insert)

    case NylasCalendar.create_event(params, token) do
      {:ok, %{"id" => id}} ->
        shoot
        |> Shoot.update_changeset(%{external_event_id: id})
        |> Repo.update!()

        Logger.info("Event created for shoot_id: #{shoot.id}")

      error ->
        Logger.error("Error #{inspect(error)}")
    end
  end

  defp get_shoot(shoot_id), do: shoot_id |> Shoots.get_shoot() |> Shoots.load_user()

  defp map_event(%{job: %{client: %{organization: %{user: user}}}} = shoot, action) do
    nylas_detail = user.nylas_detail

    {Shoot.map_event(shoot, nylas_detail, action), nylas_detail.oauth_token}
  end

  defp broadcast(nylas_detail) do
    PubSub.broadcast(
      Picsello.PubSub,
      "move_events:#{nylas_detail.id}",
      {:move_events, nylas_detail}
    )
  end
end
