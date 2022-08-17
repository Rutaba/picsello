defmodule Picsello.BookingEvents do
  @moduledoc "context module for booking events"
  alias Picsello.{Repo, BookingEvent}
  import Ecto.Query

  def upsert_booking_event(changeset) do
    changeset
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: [:id],
      returning: true
    )
  end

  def get_booking_events(organization_id) do
    organization_id
    |> booking_events_query()
    |> Repo.all()
  end

  def get_booking_event!(organization_id, event_id) do
    organization_id
    |> booking_events_query()
    |> Repo.get!(event_id)
  end

  def available_times(%BookingEvent{} = booking_event, date) do
    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        time_blocks
        |> Enum.map(fn %{start_time: start_time, end_time: end_time} ->
          duration = (booking_event.duration_minutes + (booking_event.buffer_minutes || 0)) * 60
          available_slots = (Time.diff(end_time, start_time) / duration) |> trunc()

          for slot <- 0..(available_slots - 1), available_slots > 0 do
            start_time |> Time.add(duration * slot)
          end
        end)
        |> List.flatten()
        |> filter_overlapping_shoots(booking_event, date)

      _ ->
        []
    end
  end

  defp filter_overlapping_shoots(slot_times, %BookingEvent{} = booking_event, date) do
    %{package_template: %{organization: %{user: user} = organization}} =
      booking_event
      |> Repo.preload(package_template: [organization: :user])

    beginning_of_day = DateTime.new!(date, ~T[00:00:00], user.time_zone)

    end_of_day_with_buffer =
      DateTime.new!(date, ~T[23:59:59], user.time_zone)
      |> DateTime.add((Picsello.Shoot.durations() |> Enum.max()) * 60)

    shoots =
      from(shoot in Picsello.Shoot,
        join: job in assoc(shoot, :job),
        join: client in assoc(job, :client),
        where: client.organization_id == ^organization.id and is_nil(job.archived_at),
        where: shoot.starts_at >= ^beginning_of_day and shoot.starts_at <= ^end_of_day_with_buffer
      )
      |> Repo.all()

    slot_times
    |> Enum.filter(fn slot_time ->
      slot_start = DateTime.new!(date, slot_time, user.time_zone)

      slot_end =
        slot_start
        |> DateTime.add(booking_event.duration_minutes * 60)
        |> DateTime.add(booking_event.buffer_minutes * 60 - 1)

      !Enum.any?(shoots, fn shoot ->
        start_time = shoot.starts_at |> DateTime.shift_zone!(user.time_zone)
        end_time = shoot.starts_at |> DateTime.add(shoot.duration_minutes * 60)

        (DateTime.compare(slot_start, start_time) in [:gt, :eq] &&
           DateTime.compare(slot_start, end_time) in [:lt, :eq]) ||
          (DateTime.compare(slot_end, start_time) in [:gt, :eq] &&
             DateTime.compare(slot_end, end_time) in [:lt, :eq])
      end)
    end)
  end

  defp booking_events_query(organization_id) do
    from(event in BookingEvent,
      join: package in assoc(event, :package_template),
      where: package.organization_id == ^organization_id,
      preload: [package_template: package]
    )
  end
end
