defmodule Picsello.BookingEventDate do
  @moduledoc "embedded schema module for booking events"
  use Ecto.Schema
  import Ecto.Changeset

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
      field(:status, Ecto.Enum, values: [:open, :book, :reserve, :hide], default: :open)
      field(:is_hide, :boolean, default: false, virtual: true)
    end

    def changeset(slot_block \\ %__MODULE__{}, attrs) do
      slot_block
      |> cast(attrs, [:slot_start, :slot_end, :status, :is_hide])
      |> validate_required([:slot_start, :slot_end])
      |> then(fn changeset ->
        if get_field(changeset, :is_hide),
          do: put_change(changeset, :status, :hide),
          else: put_change(changeset, :status, :open)
      end)
    end
  end

  schema "booking_event_dates" do
    field :date, :date
    field :session_gap, :integer
    field :session_length, :integer
    field :location, :string
    field :address, :string
    belongs_to :booking_event, Picsello.BookingEvent
    embeds_many :time_blocks, TimeBlock, on_replace: :delete
    embeds_many :slots, SlotBlock, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(booking_event \\ %__MODULE__{}, attrs) do
    booking_event
    |> cast(attrs, [
      :date,
      :location,
      :address,
      :booking_event_id,
      :session_length,
      :session_gap
    ])
    |> cast_embed(:time_blocks, required: true)
    |> cast_embed(:slots, required: true)
    |> validate_required([
      :date,
      :booking_event_id,
      :session_length
    ])
    |> validate_length(:time_blocks, min: 1)
    |> validate_length(:slots, min: 1)
    |> validate_time_blocks()
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
end
