defmodule Picsello.BookingEventDates do
  @moduledoc "context module for booking events dates"

  alias Picsello.{Repo, BookingEventDate}
  import PicselloWeb.PackageLive.Shared, only: [current: 1]
  import Ecto.Query

  def create_booking_event_dates(params) do
    %BookingEventDate{}
    |> BookingEventDate.changeset(params)
    |> Repo.insert()
  end

  def get_booking_events_dates(booking_event_id) do
    from(event_dates in BookingEventDate,
      where: event_dates.booking_event_id == ^booking_event_id,
      order_by: [desc: event_dates.date]
    )
    |> Repo.all()
  end

  def delete_old_repeat_dates(dates, booking_event_id) do
    from(
      event_date in BookingEventDate,
      where: event_date.date in ^dates and event_date.booking_event_id == ^booking_event_id
    )
    |> Repo.delete_all()
  end

  def upsert_booking_event_date(changeset) do
    changeset |> Repo.insert_or_update()
  end

  def generate_rows_for_repeat_dates(changeset, repeat_dates) do
    default_repeat_changeset = set_defaults_for_repeat_dates_changeset(changeset)

    Enum.map(repeat_dates, fn date ->
      default_repeat_changeset
      |> Ecto.Changeset.put_change(:date, date)
      |> current()
      |> prepare_params()
    end)
  end

  defp prepare_params(changeset) do
    changeset
    |> Map.from_struct()
    |> Map.drop([:id])
  end

  defp set_defaults_for_repeat_dates_changeset(booking_event) do
    booking_event
    |> Ecto.Changeset.change(%{
      calendar: "",
      count_calendar: nil,
      stop_repeating: nil,
      is_repeat: false,
      repetition: false,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
  end

  def available_slots(%BookingEventDate{} = booking_date, booking_event) do
    duration = (booking_date.session_length || Picsello.Shoot.durations() |> hd) * 60

    duration_buffer =
      ((booking_date.session_length || Picsello.Shoot.durations() |> hd) +
         (booking_date.session_gap || 0)) * 60

    Enum.map(booking_date.time_blocks, fn %{start_time: start_time, end_time: end_time} ->
      get_available_slots_each_block(start_time, end_time, duration, duration_buffer)
    end)
    |> Enum.filter(& &1)
    |> List.first()
    |> filter_overlapping_shoots_slots(booking_event, booking_date, false)
  end

  # "Returns all slots with status for the given booking date start_time & end_time"
  defp get_available_slots_each_block(start_time, end_time, _duration, _duration_buffer)
       when is_nil(start_time) or is_nil(end_time),
       do: []

  defp get_available_slots_each_block(start_time, end_time, duration, duration_buffer) do
    available_slots = (Time.diff(end_time, start_time) / duration) |> trunc()
    slot = 0..(available_slots - 1)

    get_available_slots_each_block(
      slot,
      available_slots,
      duration,
      duration_buffer,
      start_time,
      end_time
    )
  end

  defp get_available_slots_each_block(_slot, available_slots, _, _, _, _)
       when available_slots == 0,
       do: []

  defp get_available_slots_each_block(
         slot,
         available_slots,
         duration,
         duration_buffer,
         start_time,
         end_time
       ) do
    Enum.reduce_while(slot, [], fn x, acc ->
      duration = if x != available_slots - 1, do: duration_buffer, else: duration

      {slot_start, slot_end} =
        {Time.add(start_time, duration * x), Time.add(start_time, duration * (x + 1))}

      slot_trunc = slot_end |> Time.truncate(:second)
      time = duration * -1
      end_trunc = end_time |> Time.add(time) |> Time.truncate(:second)

      flag_type = if slot_trunc > end_trunc, do: :halt, else: :cont
      {flag_type, [%{slot_start: slot_start, slot_end: slot_end}] ++ acc}
    end)
    |> Enum.reverse()
  end

  # "Returns slots with status open or book"
  defp filter_overlapping_shoots_slots(_, _, %{date: date, session_length: session_length}, _)
       when is_nil(date) or is_nil(session_length),
       do: []

  defp filter_overlapping_shoots_slots(
         slot_times,
         booking_event,
         %{date: date} = booking_date,
         false
       ) do
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
        where:
          client.organization_id == ^organization.id and is_nil(job.archived_at) and
            is_nil(job.completed_at),
        where: shoot.starts_at >= ^beginning_of_day and shoot.starts_at <= ^end_of_day_with_buffer
      )
      |> Repo.all()
      |> Enum.map(fn shoot ->
        Map.merge(
          shoot,
          %{
            start_time: shoot.starts_at |> DateTime.shift_zone!(user.time_zone),
            end_time: shoot.starts_at |> DateTime.add(shoot.duration_minutes * 60)
          }
        )
      end)

    slot_times
    |> Enum.map(fn slot ->
      slot_start = DateTime.new!(date, slot.slot_start, user.time_zone)

      slot_end =
        slot_start
        |> DateTime.add(booking_date.session_length * 60)
        |> DateTime.add((booking_date.session_gap || 0) * 60 - 1)

      is_available =
        !Enum.any?(shoots, fn %{start_time: start_time, end_time: end_time} ->
          is_slot_booked(booking_date.session_gap, slot_start, slot_end, start_time, end_time)
        end)

      status = if is_available, do: :open, else: :booked

      Map.put(slot, :status, status)
    end)
  end

  defp is_slot_booked(session_gap, slot_start, slot_end, start_time, end_time) do
    ss_st = DateTime.compare(slot_start, start_time)
    ss_et = DateTime.compare(slot_start, end_time)
    se_st = DateTime.compare(slot_end, start_time)
    se_et = DateTime.compare(slot_end, end_time)

    if session_gap do
      (ss_st in [:gt, :eq] && ss_et in [:eq, :lt]) || (se_st in [:gt, :eq] && se_et in [:eq, :lt])
    else
      (ss_st in [:gt, :eq] && ss_et == :lt) || (se_st in [:gt, :eq] && se_et == :lt)
    end
  end

  # TODO: functionality of this handle in next PR
  def is_booked_any_date?(dates), do: false
end
