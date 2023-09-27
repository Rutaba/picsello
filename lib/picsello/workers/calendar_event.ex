defmodule Picsello.Workers.CalendarEvent do
  @moduledoc "Background job to move events from previous calendar to new"
  use Oban.Worker, queue: :storage

  alias Picsello.{NylasCalendar, NylasDetails, Accounts, Shoots, Repo}
  alias Phoenix.PubSub
  require Logger

  def perform(%Oban.Job{args: %{"type" => "insert", "shoot_id" => shoot_id}}) do
    shoot_id |> get_shoot() |> Shoots.create_event()

    :ok
  end

  def perform(%Oban.Job{args: %{"type" => "update", "shoot_id" => shoot_id}}) do
    shoot = get_shoot(shoot_id)

    if shoot.external_event_id do
      {params, token} = Shoots.map_event(shoot, :update)

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
    user = get_user(user_id)

    user
    |> Shoots.get_by_user_query()
    |> Shoots.has_external_event_query()
    |> Repo.all()
    |> Shoots.load_user()
    |> then(fn shoots ->
      task = Task.async(fn -> delete_events(shoots, user.nylas_detail) end)

      run_shoots(shoots)

      Task.await(task)
    end)

    update_nylas(user)

    :ok
  end

  def perform(%Oban.Job{args: %{"type" => "initial", "user_id" => user_id}}) do
    user = get_user(user_id)

    user
    |> Shoots.get_by_user_query()
    |> Repo.all()
    |> Shoots.load_user()
    |> run_shoots()

    update_nylas(user)

    :ok
  end

  def perform(x) do
    Logger.warning("Unknown job format #{inspect(x)}")
    :ok
  end

  defp run_shoots(shoots) do
    shoots
    |> Task.async_stream(&Shoots.create_event(&1), timeout: 10_000)
    |> Stream.run()
  end

  defp update_nylas(user) do
    user.nylas_detail
    |> NylasDetails.reset_event_status!()
    |> broadcast()
  end

  defp get_user(user_id) do
    user_id
    |> Accounts.get_user!()
    |> Repo.preload(:nylas_detail)
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

  defp get_shoot(shoot_id), do: shoot_id |> Shoots.get_shoot() |> Shoots.load_user()

  defp broadcast(nylas_detail) do
    PubSub.broadcast(
      Picsello.PubSub,
      "move_events:#{nylas_detail.id}",
      {:move_events, nylas_detail}
    )
  end
end
