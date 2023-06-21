defmodule Picsello.Shoot do
  @moduledoc false
  use Ecto.Schema
  alias Picsello.Repo
  alias Picsello.Accounts.User
  import Ecto.{Changeset, Query}

  @locations ~w[studio on_location home]a
  @durations [
    5,
    10,
    15,
    20,
    30,
    45,
    60,
    90,
    120,
    180,
    240,
    300,
    360,
    420,
    480,
    540,
    600,
    660,
    720
  ]

  @spec locations :: [:home | :on_location | :studio]
  def locations(), do: @locations

  @spec durations() ::
          [
            5
            | 10
            | 15
            | 20
            | 30
            | 45
            | 60
            | 90
            | 120
            | 180
            | 240
            | 300
            | 360
            | 420
            | 480
            | 540
            | 600
            | 660
            | 720
          ]
  def durations(), do: @durations

  schema "shoots" do
    field :duration_minutes, :integer
    field :location, Ecto.Enum, values: @locations
    field :name, :string
    field :notes, :string
    field :starts_at, :utc_datetime
    field :reminded_at, :utc_datetime
    field :thanked_at, :utc_datetime
    field :address, :string
    belongs_to(:job, Picsello.Job)

    timestamps()
  end

  # ********************************************************************************

  @spec push_changes_to_nylas(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def push_changes_to_nylas(%{valid?: false} = changeset) do
    changeset
  end

  def push_changes_to_nylas(%{valid?: true, action: action} = changeset) do
    values = Ecto.Changeset.apply_changes(changeset)
    values |> get_token_from_shoot() |> push_changes(values, action)
    changeset
  end

  @spec push_changes(Picsello.Accounts.User.t(), map(), Ecto.Changeset.action()) ::
          :ok
  def push_changes(%User{nylas_oauth_token: nil}, _values, _) do
    :ok
  end

  def push_changes(%User{external_calendar_rw_id: nil}, _values, _) do
    :ok
  end

  def push_changes(
        %User{nylas_oauth_token: token, external_calendar_rw_id: calendar_id},
        values,
        :insert
      ) do
    NylasCalendar.add_event(calendar_id, values, token)
    :ok
  end

  def push_changes(
        %User{nylas_oauth_token: token, external_calendar_rw_id: _calendar_id},
        values,
        :update
      ) do
    NylasCalendar.update_event(values, token)
    :ok
  end

  def push_changes(
        %User{nylas_oauth_token: token, external_calendar_rw_id: _calendar_id},
        values,
        :replace
      ) do
    NylasCalendar.update_event(values, token)
    :ok
  end

  def push_changes(
        %User{nylas_oauth_token: token, external_calendar_rw_id: _calendar_id},
        values,
        :delete
      ) do
    NylasCalendar.delete_event(values, token)
    :ok
  end

  def push_changes(%User{}, _values, _action) do
    :ok
  end

  @spec get_token_from_shoot(Picsello.Shoot.t()) :: Picsello.Accounts.User.t()
  def get_token_from_shoot(%__MODULE__{job_id: job_id} = _shoot) do
    query =
      from Picsello.Job,
        where: [id: ^job_id],
        preload: [client: [organization: :user]]

    result = Repo.one(query)
    result.client.organization.user
  end

  # ********************************************************************************

  def changeset_for_create_gallery(%__MODULE__{} = shoot, attrs \\ %{}) do
    shoot
    |> cast(attrs, [:starts_at, :job_id])
    |> validate_required([:starts_at])
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:starts_at, :duration_minutes, :name, :location, :notes, :job_id, :address])
    |> validate_required([:starts_at, :duration_minutes, :name, :location, :job_id])
    |> validate_inclusion(:location, @locations)
    |> validate_inclusion(:duration_minutes, @durations)
    |> prepare_changes(&__MODULE__.push_changes_to_nylas/1)
  end

  def update_changeset(%__MODULE__{} = shoot, attrs) do
    shoot
    |> cast(attrs, [:address, :starts_at, :duration_minutes, :name, :location, :notes])
    |> validate_required([:starts_at, :duration_minutes, :name, :location])
    |> validate_inclusion(:location, @locations)
    |> validate_inclusion(:duration_minutes, @durations)
    |> prepare_changes(&__MODULE__.push_changes_to_nylas/1)
  end

  def reminded_at_changeset(%__MODULE__{} = shoot) do
    shoot |> change(reminded_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def thanked_at_changeset(%__MODULE__{} = shoot) do
    shoot |> change(thanked_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def by_starts_at(query \\ __MODULE__) do
    query |> order_by(asc: :starts_at)
  end

  def for_job(job_id) do
    __MODULE__ |> where(job_id: ^job_id) |> by_starts_at()
  end

  @type t :: %__MODULE__{
          id: integer(),
          duration_minutes: integer(),
          location: String.t(),
          name: String.t(),
          notes: String.t(),
          reminded_at: DateTime.t(),
          thanked_at: DateTime.t(),
          starts_at: DateTime.t(),
          job_id: integer(),
          address: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
end
