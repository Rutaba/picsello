defmodule Picsello.NylasDetail do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset
  alias Picsello.Accounts.User

  schema "nylas_details" do
    field :oauth_token, :string
    field :previous_oauth_token, :string
    field :account_id, :string
    field :event_status, Ecto.Enum, values: [:initial, :moved, :in_progress], default: :initial
    field :external_calendar_rw_id, :string
    field :external_calendar_read_list, {:array, :string}

    belongs_to(:user, User)

    timestamps()
  end

  @type t :: %__MODULE__{
          account_id: String.t() | nil,
          oauth_token: String.t() | nil,
          previous_oauth_token: String.t() | nil,
          event_status: atom(),
          external_calendar_read_list: [String.t()] | nil,
          external_calendar_rw_id: String.t() | nil
        }

  @spec changeset(t()) :: Changeset.t()
  def changeset(nylas \\ %__MODULE__{}) do
    nylas
    |> cast(%{}, [:user_id])
  end

  @fields ~w(external_calendar_rw_id external_calendar_read_list)a
  @clear_fields Enum.into([:oauth_token | @fields], %{}, &{&1, nil})
  @token_fields ~w(account_id event_status oauth_token)a

  @spec set_token_changeset(t(), map()) :: Changeset.t()
  def set_token_changeset(%__MODULE__{} = nylas_detail, attrs) do
    nylas_detail
    |> cast(attrs, @token_fields)
    |> validate_required(@token_fields)
  end

  @spec clear_token_changeset(t()) :: Changeset.t()
  def clear_token_changeset(%__MODULE__{oauth_token: oauth_token} = nylas_detail) do
    nylas_detail
    |> change(Map.put(@clear_fields, :previous_oauth_token, oauth_token))
  end

  @spec set_calendars_changeset(t(), map()) :: Changeset.t()
  def set_calendars_changeset(%__MODULE__{} = nylas_detail, calendars) do
    nylas_detail
    |> cast(calendars, @fields)
  end

  @spec reset_event_status_changeset(t()) :: Changeset.t()
  def reset_event_status_changeset(%__MODULE__{} = nylas_detail) do
    nylas_detail
    |> change()
    |> event_status_change()
  end

  @spec event_status_change(Changeset.t()) :: Changeset.t()
  def event_status_change(changeset) do
    changeset
    |> put_change(:event_status, :moved)
    |> put_change(:previous_oauth_token, nil)
  end
end
