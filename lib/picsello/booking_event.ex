defmodule Picsello.BookingEvent do
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

  defmodule EventDate do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:date, :date)
      embeds_many :time_blocks, TimeBlock
    end

    def changeset(event_date \\ %__MODULE__{}, attrs) do
      event_date
      |> cast(attrs, [:date])
      |> cast_embed(:time_blocks, required: true)
      |> validate_required([:date])
      |> validate_length(:time_blocks, min: 1)
      |> validate_time_blocks()
    end

    defp validate_time_blocks(changeset) do
      blocks = changeset |> get_field(:time_blocks)

      overlap_times =
        for {block, index} when index > 0 <- blocks |> Enum.with_index() do
          previous_time = blocks |> Enum.at(index - 1) |> Map.get(:end_time)
          start_time = block |> Map.get(:start_time)
          !!previous_time && !!start_time && Time.compare(previous_time, start_time) == :gt
        end
        |> Enum.any?()

      if overlap_times do
        changeset |> add_error(:time_blocks, "can't be overlapping")
      else
        changeset
      end
    end
  end

  schema "booking_events" do
    field :name, :string
    field :description, :string
    field :buffer_minutes, :integer
    field :duration_minutes, :integer
    field :location, :string
    field :address, :string
    field :thumbnail_url, :string
    belongs_to :package, Picsello.Package
    embeds_many :dates, EventDate

    timestamps()
  end

  @doc false
  def changeset(booking_event, attrs) do
    booking_event
    |> cast(attrs, [
      :name,
      :location,
      :address,
      :duration_minutes,
      :buffer_minutes,
      :description,
      :thumbnail_url
    ])
    |> cast_embed(:dates, required: true)
    |> validate_required([
      :name,
      :location,
      :address,
      :duration_minutes
    ])
    |> validate_length(:dates, min: 1)
    |> validate_dates()
  end

  defp validate_dates(changeset) do
    dates = changeset |> get_field(:dates)

    same_dates =
      dates
      |> Enum.map(& &1.date)
      |> Enum.filter(& &1)
      |> Enum.group_by(& &1)
      |> Map.values()
      |> Enum.all?(&(Enum.count(&1) == 1))

    if same_dates do
      changeset
    else
      changeset |> add_error(:dates, "can't be the same")
    end
  end
end
