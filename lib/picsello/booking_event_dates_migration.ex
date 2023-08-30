defmodule Picsello.BookingEventDatesMigration do
  alias Picsello.{Repo, BookingEvent, BookingEventDate}
  import Ecto.Query

  # TODO: delete this file later
  # we are just using this file for mapping of booking_event.dates field ---> booking_event_dates table
  def available_times(%BookingEvent{} = booking_event, date, opts \\ []) do
    duration = (booking_event.duration_minutes || Picsello.Shoot.durations() |> hd) * 60

    duration_buffer =
      ((booking_event.duration_minutes || Picsello.Shoot.durations() |> hd) +
         (booking_event.buffer_minutes || 0)) * 60

    skip_overlapping_shoots = opts |> Keyword.get(:skip_overlapping_shoots, false)

    # TODO: delete this after the migration is done running
    slots =
      case booking_event.old_dates |> Enum.find(&(&1.date == date)) do
        %{time_blocks: time_blocks} ->
          Enum.map(time_blocks, fn %{start_time: start_time, end_time: end_time} ->
            get_available_slots_each_block(start_time, end_time, duration, duration_buffer)
          end)
          |> List.flatten()
          |> Enum.uniq()
          |> Enum.filter(&(!is_nil(&1)))
          |> filter_overlapping_shoots(booking_event, date, skip_overlapping_shoots)
          |> filter_is_break_slots(booking_event, date)

        _ ->
          []
      end

    re_ordered_time_blocks =
      booking_event.old_dates
      |> reorder_time_blocks()
      |> Enum.filter(&(&1.date == date))
      |> List.first()
      |> Map.get(:time_blocks)

    time_blocks = [
      %BookingEventDate.TimeBlock{
        start_time:
          re_ordered_time_blocks
          |> List.first()
          |> Map.get(:start_time),
        end_time:
          re_ordered_time_blocks
          |> List.last()
          |> Map.get(:end_time)
      }
    ]

    %{
      booking_event_id: booking_event.id,
      date: date,
      slots: slots,
      time_blocks: time_blocks,
      session_length: booking_event.duration_minutes,
      session_gap: booking_event.buffer_minutes,
      inserted_at: booking_event.inserted_at,
      updated_at: booking_event.updated_at
    }
  end

  # TODO: delete this after the migration is done running
  defp reorder_time_blocks(dates) do
    Enum.map(dates, fn %{time_blocks: time_blocks} = event_date ->
      %{event_date | time_blocks: Enum.sort_by(time_blocks, &{&1.start_time, &1.end_time})}
    end)
  end

  # TODO: delete this after the migration is done runnings
  defp get_available_slots_each_block(start_time, end_time, duration, duration_buffer) do
    if !is_nil(start_time) and !is_nil(end_time) do
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
  end

  # TODO: delete this after the migration is done running
  defp get_available_slots_each_block(
         slot,
         available_slots,
         duration,
         duration_buffer,
         start_time,
         end_time
       ) do
    if available_slots > 0 do
      Enum.reduce_while(slot, [], fn x, acc ->
        %{slot_start: slot_start, slot_end: slot_end} =
          if x != available_slots - 1 do
            %{
              slot_start: start_time |> Time.add(duration_buffer * x),
              slot_end: start_time |> Time.add(duration_buffer * (x + 1))
            }
          else
            %{
              slot_start: start_time |> Time.add(duration * x),
              slot_end: start_time |> Time.add(duration * (x + 1))
            }
          end

        slot_trunc = slot_end |> Time.truncate(:second)
        time = duration * -1
        end_trunc = end_time |> Time.add(time) |> Time.truncate(:second)

        if slot_trunc > end_trunc do
          {:halt,
           [%BookingEventDate.SlotBlock{slot_start: slot_start, slot_end: end_time}] ++ acc}
        else
          {:cont,
           [%BookingEventDate.SlotBlock{slot_start: slot_start, slot_end: slot_end}] ++ acc}
        end
      end)
      |> Enum.reverse()
    else
      []
    end
  end

  # TODO: delete this after the migration is done running
  defp filter_is_break_slots(slot_times, booking_event, date) do
    slot_times
    |> Enum.map(fn slot_time ->
      blocker_slots = filter_is_break_time_slots(booking_event, slot_time.slot_start, date)
      hidden_slots = filter_is_hidden_time_slots(booking_event, slot_time.slot_start, date)
      is_break = Enum.any?(blocker_slots)
      is_hidden = Enum.any?(hidden_slots)

      status =
        cond do
          is_break -> :break
          is_hidden -> :hide
          true -> slot_time.status
        end

      Map.put(slot_time, :status, status)
    end)
  end

  # TODO: delete this after the migration is done running
  defp filter_is_break_time_slots(booking_event, slot_time, date) do
    case booking_event.old_dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        for(
          %{
            start_time: %Time{} = start_time,
            end_time: %Time{} = end_time,
            is_break: is_break
          } <- time_blocks
        ) do
          if is_break do
            Time.compare(slot_time, start_time) in [:gt, :eq] &&
              Time.compare(slot_time, end_time) in [:lt]
          end
        end

      _ ->
        false
    end
  end

  # TODO: delete this after the migration is done running
  defp filter_is_hidden_time_slots(booking_event, slot_time, date) do
    case booking_event.old_dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        for(
          %{
            start_time: %Time{} = start_time,
            end_time: %Time{} = end_time,
            is_hidden: is_hidden
          } <- time_blocks
        ) do
          if is_hidden do
            Time.compare(slot_time, start_time) in [:gt, :eq] &&
              Time.compare(slot_time, end_time) in [:lt]
          end
        end

      _ ->
        false
    end
  end

  # TODO: delete this after the migration is done running
  # defp filter_overlapping_shoots(slot_times, _booking_event, _date, true) do
  #   slot_times |> Enum.map(fn slot_time -> {slot_time, true, true, true} end)
  # end

  # TODO: delete this after the migration is done running
  defp filter_overlapping_shoots(
         slot_times,
         %BookingEvent{} = booking_event,
         date,
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

    slot_times
    |> Enum.map(fn slot_time ->
      slot_start = DateTime.new!(date, slot_time.slot_start, user.time_zone)

      slot_end =
        slot_start
        |> DateTime.add(booking_event.duration_minutes * 60)
        |> DateTime.add((booking_event.buffer_minutes || 0) * 60 - 1)

      is_available =
        !Enum.any?(shoots, fn shoot ->
          start_time = shoot.starts_at |> DateTime.shift_zone!(user.time_zone)
          end_time = shoot.starts_at |> DateTime.add(shoot.duration_minutes * 60)
          is_slot_booked(booking_event.buffer_minutes, slot_start, slot_end, start_time, end_time)
        end)

      status = if is_available, do: :open, else: :book
      Map.put(slot_time, :status, status)
    end)
  end

  defp is_slot_booked(nil, slot_start, slot_end, start_time, end_time) do
    (DateTime.compare(slot_start, start_time) in [:gt, :eq] &&
       DateTime.compare(slot_start, end_time) == :lt) ||
      (DateTime.compare(slot_end, start_time) in [:gt, :eq] &&
         DateTime.compare(slot_end, end_time) == :lt)
  end

  defp is_slot_booked(_buffer, slot_start, slot_end, start_time, end_time) do
    (DateTime.compare(slot_start, start_time) in [:gt, :eq] &&
       DateTime.compare(slot_start, end_time) in [:lt, :eq]) ||
      (DateTime.compare(slot_end, start_time) in [:gt, :eq] &&
         DateTime.compare(slot_end, end_time) in [:lt, :eq])
  end
end
