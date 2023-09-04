defmodule Picsello.BookingEventDate do
  @moduledoc """
  This module defines the schema for booking event dates, including embedded schemas for time blocks, slot blocks, and repeat day blocks.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Client, BookingEventDates}

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
      field(:status, Ecto.Enum, values: [:open, :book, :reserve, :hide], default: :open)
      field(:is_hide, :boolean, default: false, virtual: true)
    end

    def changeset(slot_block \\ %__MODULE__{}, attrs) do
      slot_block
      |> cast(attrs, [:slot_start, :slot_end, :client_id, :status, :is_hide])
      |> validate_required([:slot_start, :slot_end])
      |> then(fn changeset ->
        if get_field(changeset, :is_hide),
          do: put_change(changeset, :status, :hide),
          else: put_change(changeset, :status, :open)
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
      else
        changeset
      end
    end)
  end

  # This is to validate whether a booking-event-date already exists within a booking-event
  defp validate_booking_event_date(changeset) do
    booking_event_id = get_field(changeset, :booking_event_id)

    if get_field(changeset, :date) do
      date = get_field(changeset, :date)
      booking_event_date_id = get_field(changeset, :id)

      booking_event_dates =
        BookingEventDates.get_booking_events_dates_with_same_date(booking_event_id, date)

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

  defp validate_stop_repeating(changeset) do
    repetition_value = get_field(changeset, :repetition)

    {key, value} = if repetition_value, do: {:stop_repeating, nil}, else: {:occurences, 0}
    changeset = put_change(changeset, key, value)

    occurences = get_field(changeset, :occurences)
    stop_repeating = get_field(changeset, :stop_repeating)

    if occurences == 0 and is_nil(stop_repeating),
      do: changeset |> add_error(:repetition, "Either occurence or date should be selected"),
      else: changeset
  end

  defp validate_time_blocks(changeset) do
    blocks = changeset |> get_field(:time_blocks)

    overlap_times =
      for(
        [%{end_time: %Time{} = previous_time}, %{start_time: %Time{} = start_time}] <-
          Enum.chunk_every(blocks, 2, 1),
        do: Time.compare(previous_time, start_time) == :gt
      )
      |> Enum.any?()

    if overlap_times do
      changeset |> add_error(:time_blocks, "can't be overlapping")
    else
      changeset
    end
  end

  defp set_default_repeat_on(changeset) do
    if Enum.empty?(get_field(changeset, :repeat_on)) do
      put_change(changeset, :repeat_on, [
        %{day: "sun", active: true},
        %{day: "mon", active: false},
        %{day: "tue", active: false},
        %{day: "wed", active: false},
        %{day: "thu", active: false},
        %{day: "fri", active: false},
        %{day: "sat", active: false}
      ])
    else
      changeset
    end
  end
end
