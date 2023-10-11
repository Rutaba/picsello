defmodule Picsello.BookingEventDate do
  @moduledoc """
  This module defines the schema for booking event dates, including embedded schemas for time blocks, slot blocks, and repeat day blocks.
  """
  use Ecto.Schema

  import Ecto.Changeset
  alias Picsello.{Client, Job, BookingEventDates, BookingEvents}

  defmodule TimeBlock do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:start_time, :time)
      field(:end_time, :time)
    end

    def changeset(time_block \\ %__MODULE__{}, attrs) do
      time_block
      |> cast(attrs, [:start_time, :end_time])
      |> validate_required([:start_time, :end_time])
      |> validate_end_time()
    end

    defp validate_end_time(changeset) do
      start_time = get_field(changeset, :start_time)
      end_time = get_field(changeset, :end_time)

      if start_time && end_time && Time.compare(start_time, end_time) == :gt do
        changeset |> add_error(:end_time, "cannot be before start time")
      else
        changeset
      end
    end
  end

  defmodule SlotBlock do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:slot_start, :time)
      field(:slot_end, :time)
      belongs_to(:client, Client)
      belongs_to(:job, Job)
      field(:status, Ecto.Enum, values: [:open, :booked, :reserved, :hidden], default: :open)
      field(:is_hide, :boolean, default: false, virtual: true)
    end

    @type t :: %__MODULE__{
            job_id: integer(),
            client_id: integer(),
            status: atom()
          }

    def changeset(slot_block \\ %__MODULE__{}, attrs) do
      slot_block
      |> cast(attrs, [:slot_start, :slot_end, :client_id, :job_id, :status, :is_hide])
      |> validate_required([:slot_start, :slot_end])
      |> then(fn changeset ->
        cond do
          get_field(changeset, :is_hide) ->
            put_change(changeset, :status, :hidden)

          get_field(changeset, :status) not in [:booked, :reserved] ->
            put_change(changeset, :status, :open)

          true ->
            changeset
        end
      end)
    end
  end

  defmodule RepeatDayBlock do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:day, :string)
      field(:active, :boolean, default: false)
    end

    def changeset(repeat_day \\ %__MODULE__{}, attrs) do
      repeat_day
      |> cast(attrs, [:day, :active])
      |> validate_required([:day, :active])
    end
  end

  schema "booking_event_dates" do
    field :date, :date
    field :session_gap, :integer
    field :session_length, :integer
    field :location, :string
    field :address, :string
    field :calendar, :string
    field :count_calendar, :integer
    field :stop_repeating, :date
    field :occurences, :integer, default: 0
    embeds_many :repeat_on, RepeatDayBlock, on_replace: :delete
    field :organization_id, :integer, virtual: true
    field :is_repeat, :boolean, default: false, virtual: true
    field :repetition, :boolean, default: false, virtual: true
    belongs_to :booking_event, Picsello.BookingEvent
    embeds_many :time_blocks, TimeBlock, on_replace: :delete
    embeds_many :slots, SlotBlock, on_replace: :delete

    timestamps()
  end

  @required_attrs [
    :booking_event_id,
    :session_length,
    :date
  ]

  @doc false
  def changeset(booking_event \\ %__MODULE__{}, attrs) do
    booking_event
    |> cast(attrs, [
      :date,
      :location,
      :address,
      :booking_event_id,
      :session_length,
      :session_gap,
      :count_calendar,
      :calendar,
      :stop_repeating,
      :occurences,
      :is_repeat,
      :repetition
    ])
    |> cast_embed(:time_blocks, required: true)
    |> cast_embed(:slots, required: true)
    |> cast_embed(:repeat_on)
    |> validate_required(@required_attrs)
    |> validate_length(:time_blocks, min: 1)
    |> validate_length(:slots, min: 1)
    |> validate_time_blocks()
    |> set_default_repeat_on()
    |> validate_booking_event_date()
    |> then(fn changeset ->
      if get_field(changeset, :is_repeat) do
        changeset
        |> validate_required([:count_calendar, :calendar])
        |> validate_stop_repeating()
        |> validate_repeat_date_overlapping()
      else
        changeset
      end
    end)
  end

  def update_slot_changeset(booking_event_date, slot_index, slot_update_args) do
    slot =
      booking_event_date.slots
      |> Enum.at(slot_index)
      |> Map.merge(slot_update_args)

    booking_event_date
    |> change(slots: List.replace_at(booking_event_date.slots, slot_index, slot))
  end

  # This is to validate whether a booking-event-date already exists within a booking-event
  defp validate_booking_event_date(changeset) do
    booking_event_id = get_field(changeset, :booking_event_id)

    if get_field(changeset, :date) do
      [date, booking_event_date_id] = get_fields(changeset, [:date, :id])

      booking_event_dates =
        BookingEventDates.get_booking_events_dates_with_same_date([booking_event_id], date)

      booking_event_dates =
        if booking_event_date_id,
          do:
            booking_event_dates
            |> Enum.filter(&(&1.id != booking_event_date_id)),
          else: booking_event_dates

      if Enum.any?(booking_event_dates),
        do: changeset |> add_error(:date, "is already selected"),
        else: changeset
    else
      changeset
    end
  end

  # Validates the `stop_repeating` field based on the `repetition` field.
  defp validate_stop_repeating(changeset) do
    repetition_value = get_field(changeset, :repetition)

    {key, value} = if repetition_value, do: {:stop_repeating, nil}, else: {:occurences, 0}
    changeset = put_change(changeset, key, value)

    [occurences, stop_repeating] = get_fields(changeset, [:occurences, :stop_repeating])

    if occurences == 0 and is_nil(stop_repeating),
      do: changeset |> add_error(:repetition, "Either occurence or date should be selected"),
      else: changeset
  end

  # Validates the time blocks to ensure they do not overlap with existing blocks.
  defp validate_time_blocks(changeset) do
    [date, organization_id, current_time_block, date_id] =
      get_fields(changeset, [:date, :organization_id, :time_blocks, :id])

    if is_nil(date) do
      changeset
    else
      overlap_times? =
        BookingEventDates.booking_date_time_block_overlap?(
          organization_id,
          date,
          current_time_block,
          date_id
        )

      if overlap_times? do
        changeset |> add_error(:time_blocks, "can't be overlapping")
      else
        changeset
      end
    end
  end

  # Validates repeat dates to ensure they do not overlap with existing bookings.
  defp validate_repeat_date_overlapping(changeset) do
    repeat_dates = get_repeat_dates(changeset)

    [booking_event_id, organization_id, blocks] =
      get_fields(changeset, [:booking_event_id, :organization_id, :time_blocks])

    repeat_date_overlap_any_booking_event? =
      BookingEventDates.repeat_dates_overlap?(
        organization_id,
        blocks,
        repeat_dates,
        booking_event_id
      )

    if repeat_date_overlap_any_booking_event? do
      changeset
      |> add_error(
        :is_repeat,
        "repeat date is overlapping"
      )
    else
      changeset
    end
  end

  # Sets default values for the `repeat_on` field if it is empty.
  @default_values [
    %{day: "sun", active: true},
    %{day: "mon", active: false},
    %{day: "tue", active: false},
    %{day: "wed", active: false},
    %{day: "thu", active: false},
    %{day: "fri", active: false},
    %{day: "sat", active: false}
  ]
  defp set_default_repeat_on(changeset) do
    if changeset |> get_field(:repeat_on) |> Enum.empty?() do
      put_change(changeset, :repeat_on, @default_values)
    else
      changeset
    end
  end

  # Gets a list of repeat dates based on selected days of the week.
  defp get_repeat_dates(changeset) do
    selected_days = get_field(changeset, :repeat_on) |> Enum.map(&Map.from_struct(&1))

    changeset
    |> Ecto.Changeset.apply_changes()
    |> BookingEvents.calculate_dates(selected_days)
  end

  defp get_fields(changeset, keys) do
    for key <- keys, do: get_field(changeset, key)
  end
end
