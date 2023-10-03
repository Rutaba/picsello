defmodule Picsello.BookingEventDates do
  @moduledoc "context module for booking events dates"

  alias Picsello.{
    Repo,
    Shoots,
    BookingEventDate,
    BookingEventDate.SlotBlock,
    BookingEvent,
    BookingEvents
  }

  alias Ecto.Changeset
  import Ecto.Query
  import Ecto.Changeset

  @doc """
  Creates and inserts a new BookingEventDate record into the database.

  This function creates a new `BookingEventDate` record using the provided parameters and inserts it into
  the database. It returns either a successful `{:ok, %BookingEventDate{}}` tuple with the created record
  or an `{:error, Changeset.t()}` tuple with validation errors if the insertion fails.

  ## Parameters

  - `params` (map()): A map containing the attributes and values for the new `BookingEventDate` record to be
    created.

  ## Returns

  - `{:ok, %BookingEventDate{}}`: A successful tuple containing the created `BookingEventDate` record if the
    insertion is successful.
  - `{:error, Changeset.t()}`: An error tuple containing an `Changeset` with validation errors if
    the insertion fails.

  ## Example

  ```elixir
  # Create a new BookingEventDate record
  iex> params = %{booking_event_id: 123, date: ~D[2023-09-07], session_length: 120}
  iex> result = create_booking_event_dates(params)
  iex> case result do
  ...>   {:ok, booking_event_date} -> booking_event_date
  ...>   {:error, changeset} -> changeset.errors
  ...> end
  """
  @spec create_booking_event_dates(params :: map()) ::
          {:ok, %{}} | {:error, Changeset.t()}
  def create_booking_event_dates(params) do
    %BookingEventDate{}
    |> BookingEventDate.changeset(params)
    |> Repo.insert()
  end

  def update_booking_event_dates(booking_date, attrs) do
    booking_date
    |> change(attrs)
    |> Repo.update()
  end

  def update_booking_event_date_slots(booking_event, booking_date) do
    slots = update_slots_status(booking_event, booking_date)
    update_booking_event_dates(booking_date, %{slots: slots})
  end

  def get_booking_date(id) do
    from(
      event_date in BookingEventDate,
      where: event_date.id == ^id,
      preload: :booking_event
    )
    |> Repo.one!()
  end

  def delete_booking_date(id),
    do:
      id
      |> get_booking_date()
      |> Repo.delete()

  @doc """
  Retrieves a list of booking event dates associated with the given booking event ID.

  ## Parameters

  - `booking_event_id` (integer()): The unique identifier of the
  booking event for which you want to retrieve dates.

  ## Returns

  A list of `BookingEventDate` structs representing the dates associated
  with the specified booking event. The list is ordered in descending order by date.

  ## Examples

  ```elixir
  iex> booking_event_id = 123
  iex> get_booking_events_dates(booking_event_id)
  [
    %BookingEventDate{
      id: 1,
      booking_event_id: 123,
      date: ~D[2023-09-07],
      # ... other fields
    },
    %BookingEventDate{
      id: 2,
      booking_event_id: 123,
      date: ~D[2023-09-08],
      # ... other fields
    },
    # ... more dates
  ]
  """
  @spec get_booking_events_dates(booking_event_id :: integer()) :: [BookingEventDate.t()]
  def get_booking_events_dates(booking_event_id),
    do: booking_events_dates_query([booking_event_id]) |> Repo.all()

  @doc """
  Retrieves a list of booking event dates associated with the specified booking event IDs that have the same date.

  ## Parameters

  - `booking_event_ids` ([integer()]): A list of unique identifiers for booking events to filter by.
  - `date` (Date.t()): The date to match for filtering the booking event dates.

  ## Returns

  A list of `BookingEventDate` structs representing the dates associated with the specified booking events that have the same date as the given `date`.

  ## Examples

  ```elixir
  iex> booking_event_ids = [123, 456]
  iex> target_date = ~D[2023-09-07]
  iex> get_booking_events_dates_with_same_date(booking_event_ids, target_date)
  [
    %BookingEventDate{
      id: 1,
      booking_event_id: 123,
      date: ~D[2023-09-07],
      # ... other fields
    },
    %BookingEventDate{
      id: 3,
      booking_event_id: 456,
      date: ~D[2023-09-07],
      # ... other fields
    },
    # ... more dates with the same date
  ]
  """
  @spec get_booking_events_dates_with_same_date(
          booking_event_ids :: [integer()],
          date :: Date.t()
        ) :: [BookingEventDate.t()]
  def get_booking_events_dates_with_same_date(booking_event_ids, date) do
    booking_events_dates_query(booking_event_ids)
    |> where(date: ^date)
    |> Repo.all()
  end

  @doc "gets a single booking_Event_date that has the given id"
  def get_booking_event_date(date_id) do
    date_id
    |> booking_event_date_query()
    |> Repo.one()
  end

  @doc "deletes a single booking_Event_date that has the given id"
  def delete_booking_event_date(date_id) do
    date_id
    |> get_booking_event_date()
    |> Repo.delete()
  end

  @doc """
  Constructs a database query for retrieving booking event dates
  associated with specific dates and a booking event ID.

  This function takes a list of `dates` and a `booking_event_id` and creates
  a query to fetch `BookingEventDate` records where the `date` matches one of
  the dates in the provided list and the `booking_event_id` matches the given
  `booking_event_id`.

  ## Parameters

  - `dates` ([Date.t()]): A list of dates to match when filtering booking event dates.
  - `booking_event_id` (integer()): The unique identifier of the booking event to filter by.

  ## Returns

  A database query for fetching `BookingEventDate` records that match the specified
  `dates` and `booking_event_id`.

  ## Example

  ```elixir
  iex> dates = [~D[2023-09-07], ~D[2023-09-08]]
  iex> booking_event_id = 123
  iex> query = repeat_dates_queryable(dates, booking_event_id)
  iex> Repo.all(query)
  """
  @spec repeat_dates_queryable(dates :: [Date.t()], booking_event_id :: integer()) ::
          Ecto.Query.t()
  def repeat_dates_queryable(dates, booking_event_id) do
    from(
      event_date in BookingEventDate,
      where: event_date.date in ^dates and event_date.booking_event_id == ^booking_event_id
    )
  end

  def update_slot_status(booking_event_date_id, slot_index, slot_update_args) do
    get_booking_date(booking_event_date_id)
    |> BookingEventDate.update_slot_changeset(slot_index, slot_update_args)
    |> upsert_booking_event_date()
  end

  @doc """
  Upserts (Insert or Update) a booking event date into the database.

  This function takes an Ecto changeset representing a `BookingEventDate` and attempts to
  insert it into the database. If a record with the same primary key exists, it will
  be updated. If not, a new record will be inserted.

  ## Parameters

  - `changeset` (Changeset.t()): An Ecto changeset representing the changes to be made
    to the `BookingEventDate` record.

  ## Returns

  - `{:ok, BookingEventDate.t()}`: If the upsert operation is successful, it returns `{:ok, record}`
    where `record` is the inserted or updated `BookingEventDate` struct.
  - `{:error, Changeset.t()}`: If there are errors during the upsert operation, it returns
    `{:error, changeset}` with the changeset containing validation or other errors.

  ## Example

  ```elixir
  # Create a changeset for a new booking event date
  iex> changeset = BookingEventDate.changeset(%BookingEventDate{date: ~D[2023-09-07]}, %{})
  iex> {:ok, result} = upsert_booking_event_date(changeset)
  iex> IO.inspect(result)
  %BookingEventDate{
    id: 1,
    date: ~D[2023-09-07],
    # ... other fields
  }

  # Update an existing booking event date
  iex> changeset = BookingEventDate.changeset(existing_record, %{date: ~D[2023-09-08]})
  iex> {:ok, result} = upsert_booking_event_date(changeset)
  iex> result
  %BookingEventDate{
    id: 1,
    date: ~D[2023-09-08],
    # ... other updated fields
  }
  """
  @spec upsert_booking_event_date(changeset :: Changeset.t()) ::
          {:ok, BookingEventDate.t()} | {:error, Changeset.t()}
  def upsert_booking_event_date(changeset) do
    changeset |> Repo.insert_or_update()
  end

  @doc """
  Generates a list of Ecto changesets for inserting multiple `BookingEventDate` rows
  with specified repeat dates based on a provided changeset.

  This function takes an Ecto changeset representing a `BookingEventDate` record and a list
  of `repeat_dates`. It generates a list of Ecto changesets, each representing a new row
  with a different date, based on the provided changeset. The generated changesets will have
  the same field values as the original changeset, except for the `date` field, which will
  be set to each date in the `repeat_dates` list.

  ## Parameters

  - `changeset` (Changeset.t()): An Ecto changeset representing the common attributes
    for all generated `BookingEventDate` records.
  - `repeat_dates` ([Date.t()]): A list of dates for which to generate new records.

  ## Returns

  A list of Ecto changesets, each representing a new `BookingEventDate` record with the same
  attributes as the provided `changeset`, except for the `date` field, which varies based on
  the dates in the `repeat_dates` list.

  ## Example

  ```elixir
  # Create a common changeset with shared attributes
  iex> common_changeset = BookingEventDate.changeset(%BookingEventDate{booking_event_id: 123}, %{})

  # Generate changesets for multiple repeat dates
  iex> repeat_dates = [~D[2023-09-07], ~D[2023-09-08], ~D[2023-09-09]]
  iex> changesets = generate_rows_for_repeat_dates(common_changeset, repeat_dates)
  iex> Enum.each(changesets, fn changeset ->
  ...>   {:ok, result} = Repo.insert(changeset)
  ...>   result
  ...> end)
  """
  @spec generate_rows_for_repeat_dates(
          changeset :: Changeset.t(),
          repeat_dates :: [Date.t()]
        ) :: [Changeset.t()]
  def generate_rows_for_repeat_dates(changeset, repeat_dates) do
    default_repeat_changeset = set_defaults_for_repeat_dates_changeset(changeset)

    Enum.map(repeat_dates, fn date ->
      default_repeat_changeset
      |> Changeset.put_change(:date, date)
      |> Changeset.apply_changes()
      |> prepare_params()
    end)
  end

  @doc """
  Transforms a list of slot blocks by applying a default transformation to each slot.

  This function takes a list of slot blocks (`input_slots`) and applies a default transformation to each slot using
  the `transform_slot/1` private function. The default transformation updates the `client_id` to `nil`, `job_id` to `nil` and sets the
  `status` to `:open`. The resulting list of transformed slot blocks is returned.

  ## Parameters

  - `input_slots` ([%SlotBlock{}]): A list of slot blocks to be transformed.

  ## Returns

  A list of slot blocks with default transformations applied.

  ## Example

  ```elixir
  # Transform a list of slot blocks with default values
  iex> input_slots = [%SlotBlock{job_id: 1, client_id: 1, status: :hidden}, %SlotBlock{job_id: 1, client_id: 2, status: :booked}]
  iex> transform_slots(input_slots)
  [%SlotBlock{job_id: nil, client_id: nil, status: :open}, %SlotBlock{job_id: nil, client_id: nil, status: :open}]

  ## Notes
  This function is useful for applying a consistent default transformation to a list of slot blocks.
  """
  @spec transform_slots(input_slots :: [SlotBlock.t()]) :: [SlotBlock.t()]
  def transform_slots(input_slots), do: Enum.map(input_slots, &transform_slot/1)

  defp transform_slot(slot) do
    cond do
      slot.status in [:booked, :reserved] ->
        %SlotBlock{
          slot
          | client_id: nil,
            job_id: nil,
            status: :open
        }

      slot.status == :hidden ->
        %SlotBlock{slot | is_hide: true}

      true ->
        slot
    end
  end

  @doc """
  Retrieves available time slots for booking within a BookingEventDate.

  This function calculates available time slots within a given `BookingEventDate` based on the session length,
  session gap, and existing bookings. It considers the session length from the `booking_date` if specified;
  otherwise, it uses the default session length. The availability is calculated for each time block in the date.

  ## Parameters

  - `booking_date` (%BookingEventDate{}): A struct representing the booking date for which you want to find available slots.
  - `booking_event` (%BookingEvent{}): A struct representing the booking event to which the date belongs.

  ## Returns

  A list of available time slots (SlotBlock.t()) within the specified `booking_date`. If no available slots
  are found, the function returns `nil`.

  ## Example

  ```elixir
  # Retrieve available slots for a BookingEventDate
  iex> booking_date = %BookingEventDate{
  ...>   id: 1,
  ...>   time_blocks: [
  ...>     %{start_time: "09:00", end_time: "12:00"},
  ...>     %{start_time: "13:00", end_time: "16:00"}
  ...>   ],
  ...>   session_length: 120, # in minutes
  ...>   session_gap: 15 # in minutes
  ...> }

  iex> booking_event = %BookingEvent{
  ...>   id: 123,
  ...>   # ... other fields
  ...> }

  iex> available_slots(booking_date, booking_event)
  [
    %SlotBlock{
      id: 1,
      booking_event_id: 123,
      booking_event_date_id: 1,
      start_time: "09:00",
      end_time: "11:00",
      # ... other fields
    },
    %SlotBlock{
      id: 2,
      booking_event_id: 123,
      booking_event_date_id: 1,
      start_time: "13:15",
      end_time: "15:15",
      # ... other fields
    },
    # ... more available slots
  ]
  """
  @spec available_slots(booking_date :: BookingEventDate.t(), booking_event :: BookingEvent.t()) ::
          [SlotBlock.t()] | nil
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

  # Constructs a database query to retrieve booking event dates
  defp booking_events_dates_query(booking_event_ids) do
    from(event_date in BookingEventDate,
      where: event_date.booking_event_id in ^booking_event_ids,
      order_by: [desc: event_date.date]
    )
  end

  # Prepares and extracts parameters from an Ecto changeset for insertion or update.
  defp prepare_params(changeset) do
    changeset
    |> Map.from_struct()
    |> Map.drop([:id, :__meta__, :booking_event, :is_repeat, :organization_id, :repetition])
  end

  # Sets default values for a changeset representing a `BookingEventDate` record with repeat dates.
  defp set_defaults_for_repeat_dates_changeset(booking_event) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    booking_event
    |> Changeset.change(%{
      calendar: "",
      count_calendar: nil,
      stop_repeating: nil,
      is_repeat: false,
      repetition: false,
      inserted_at: now,
      updated_at: now
    })
  end

  # Returns all slots with status for the given booking date start_time & end_time
  defp get_available_slots_each_block(start_time, end_time, _duration, _duration_buffer)
       when is_nil(start_time) or is_nil(end_time),
       do: []

  # Recursively calculates available time slots within a given time block.
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

  # Base case of the recursive function that returns an empty list.
  defp get_available_slots_each_block(_slot, available_slots, _, _, _, _)
       when available_slots == 0,
       do: []

  # Recursively calculates available time slots within a given time block.
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
      {flag_type, [%SlotBlock{slot_start: slot_start, slot_end: slot_end} | acc]}
    end)
    |> Enum.reverse()
  end

  # Returns slots with status open or book
  defp filter_overlapping_shoots_slots(_, _, %{date: date, session_length: session_length}, _)
       when is_nil(date) or is_nil(session_length),
       do: []

  # Filters time slots based on overlapping shoots and assigns booking status.
  defp filter_overlapping_shoots_slots(slot_times, booking_event, booking_date, false) do
    booking_date = Map.put(booking_date, :slots, slot_times)
    update_slots_status(booking_event, booking_date)
  end

  defp update_slots_status(booking_event, booking_date) do
    %{date: date, session_length: session_length, session_gap: session_gap, slots: slot_times} =
      booking_date

    %{package_template: %{organization: %{user: user}}} =
      booking_event
      |> Repo.preload(package_template: [organization: :user])

    beginning_of_day = DateTime.new!(date, ~T[00:00:00], user.time_zone)

    end_of_day_with_buffer =
      DateTime.new!(date, ~T[23:59:59], user.time_zone)
      |> DateTime.add((Picsello.Shoot.durations() |> Enum.max()) * 60)

    shoots = Shoots.get_shoots_for_booking_event(user, beginning_of_day, end_of_day_with_buffer)

    slot_times
    |> Enum.map(fn slot ->
      slot_start = DateTime.new!(date, slot.slot_start, user.time_zone)

      slot_end =
        slot_start
        |> DateTime.add(session_length * 60)
        |> DateTime.add((session_gap || 0) * 60 - 1)

      slot_booked =
        Enum.reduce_while(shoots, %{is_booked: false, client_id: nil, job_id: nil}, fn shoot,
                                                                                       acc ->
          is_booked =
            is_slot_booked?(session_gap, slot_start, slot_end, shoot.start_time, shoot.end_time)

          if is_booked do
            {:halt, %{is_booked: is_booked, client_id: shoot.job.client.id, job_id: shoot.job.id}}
          else
            {:cont, acc}
          end
        end)

      slot_status = Map.get(slot, :status, :open)

      status =
        cond do
          slot_booked.is_booked -> :booked
          !slot_booked.is_booked and is_nil(slot_booked.job_id) -> :open
          true -> slot_status
        end

      slot
      |> Map.put(:status, status)
      |> Map.put(:client_id, slot_booked.client_id)
      |> Map.put(:job_id, slot_booked.job_id)
    end)
  end

  # Checks if a time slot is booked based on overlapping time ranges.
  defp is_slot_booked?(session_gap, slot_start, slot_end, start_time, end_time) do
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

  @doc """
  Checks if any time slot for a given booking event on the specified dates is booked.

  This function checks if any time slot for a particular booking event, identified by `booking_event_id`,
  is booked on the specified list of `repeat_dates`. It queries the database for booking event dates
  associated with each date and checks if any of their time slots have a booking status of `:booked`.

  ## Parameters

  - `repeat_dates` ([Date.t()]): A list of dates for which to check if any time slots are booked.
  - `booking_event_id` (integer()): The unique identifier of the booking event to check.

  ## Returns

  `true` if any time slot for the specified booking event is booked on any of the provided `repeat_dates`,
  `false` otherwise.

  ## Example

  ```elixir
  iex> repeat_dates = [~D[2023-09-07], ~D[2023-09-08]]
  iex> booking_event_id = 123
  iex> is_booked_any_date?(repeat_dates, booking_event_id)
  true
  """
  @spec is_booked_any_date?(repeat_dates :: [Date.t()], booking_event_id :: integer()) ::
          boolean()
  def is_booked_any_date?(repeat_dates, booking_event_id) do
    booked? = fn %{slots: slots} -> Enum.any?(slots, &(&1.status == :booked)) end

    Enum.any?(repeat_dates, fn date ->
      [booking_event_id]
      |> get_booking_events_dates_with_same_date(date)
      |> Enum.any?(&booked?.(&1))
    end)
  end

  @doc """
  Checks if there is any overlap between booking date time blocks and provided blocks.

  This function checks if there is any overlap between the time blocks of a booking date and the
  provided list of blocks. It is typically used to ensure that there are no conflicting time slots
  when creating or updating booking events for a specific organization on a specific date.

  ## Parameters

  - `organization_id` (integer()): The unique identifier of the organization for which the check is performed.
  - `date` (Date.t()): The date for which the check is performed.
  - `blocks` ([BookingEventDate.t()]): A list of time blocks to compare against the time blocks of the
    booking date.
  - `event_date_id` (integer()): The unique identifier of the event date for which the check is performed.

  ## Returns

  `true` if there is an overlap between the time blocks of the booking date and the provided blocks,
  indicating potential conflicts. `false` otherwise.

  ## Example

  ```elixir
  iex> organization_id = 123
  iex> date = ~D[2023-09-07]
  iex> blocks = [%BookingEventDate{...}, %BookingEventDate{...}]
  iex> event_date_id = 111
  iex> booking_date_time_block_overlap?(organization_id, date, blocks, event_date_id)
  true
  iex> booking_date_time_block_overlap?(organization_id, nil, blocks, event_date_id)
  false
  """
  def booking_date_time_block_overlap?(_organization_id, nil, _blocks, _event_date_id), do: false

  @spec booking_date_time_block_overlap?(
          organization_id :: integer(),
          date :: Date.t(),
          blocks :: [BookingEventDate.t()],
          event_date_id :: integer()
        ) :: boolean()
  def booking_date_time_block_overlap?(organization_id, date, blocks, event_date_id) do
    organization_id
    |> BookingEvents.get_all_booking_events()
    |> Enum.map(& &1.id)
    |> is_date_time_block_overlap?(date, blocks, event_date_id)
  end

  @doc """
  Checks if there is any overlap between repeat dates and booking date time blocks.

  This function checks if there is any overlap between a list of repeat dates and the time blocks of a booking date.
  It is typically used to ensure that there are no conflicting time slots when creating or updating booking events
  for a specific organization.

  ## Parameters

  - `organization_id` (integer()): The unique identifier of the organization for which the check is performed.
  - `blocks` ([BookingEventDate.t()]): A list of time blocks to compare against the time blocks of booking dates.
  - `repeat_dates` ([Date.t()]): A list of repeat dates for which the overlap is checked.
  - `current_booking_event_id` (integer()): The unique identifier of the current booking event to exclude from
    the check.

  ## Returns

  `true` if there is an overlap between the repeat dates and the time blocks of booking dates, indicating potential
  conflicts. `false` otherwise.

  ## Example

  ```elixir
  iex> organization_id = 123
  iex> blocks = [%BookingEventDate{...}, %BookingEventDate{...}]
  iex> repeat_dates = [~D[2023-09-07], ~D[2023-09-08]]
  iex> current_booking_event_id = 456
  iex> repeat_dates_overlap?(organization_id, blocks, repeat_dates, current_booking_event_id)
  true
  iex> repeat_dates_overlap?(organization_id, blocks, [], current_booking_event_id)
  false
  """
  def repeat_dates_overlap?(_organization_id, _blocks, [], _current_booking_event), do: false

  @spec repeat_dates_overlap?(
          organization_id :: integer(),
          blocks :: [BookingEventDate.t()],
          repeat_dates :: [Date.t()],
          current_booking_event_id :: integer()
        ) :: boolean()
  def repeat_dates_overlap?(organization_id, blocks, repeat_dates, current_booking_event_id) do
    booking_ids =
      BookingEvents.get_all_booking_events(organization_id)
      |> Enum.map(& &1.id)
      |> Enum.reject(&(&1 == current_booking_event_id))

    repeat_dates
    |> Enum.any?(fn date ->
      is_date_time_block_overlap?(booking_ids, date, blocks)
    end)
  end

  # Checks if there is any overlap between booking date time blocks and provided blocks.
  defp is_date_time_block_overlap?(booking_ids, date, blocks, date_id \\ nil) do
    booking_ids
    |> get_booking_events_dates_with_same_date(date)
    |> Enum.reject(&(&1.id == date_id))
    |> Enum.flat_map(& &1.time_blocks)
    |> Enum.concat(blocks)
    |> Enum.sort_by(&{&1.start_time, &1.end_time})
    |> BookingEvents.overlap_time?()
  end

  defp booking_event_date_query(date_id),
    do:
      from(event_date in BookingEventDate,
        where: event_date.id == ^date_id
      )
end
