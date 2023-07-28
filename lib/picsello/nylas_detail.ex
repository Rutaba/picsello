defmodule Picsello.NylasDetail do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Repo, Accounts.User, Workers.CalendarEvent}
  alias Ecto.Multi

  schema "nylas_details" do
    field :oauth_token, :string
    field :previous_oauth_token, :string
    field :account_id, :string
    field :event_status, Ecto.Enum, values: [:moved, :in_progress], default: :moved
    field :external_calendar_rw_id, :string
    field :external_calendar_read_list, {:array, :string}

    belongs_to(:user, User)

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          account_id: String.t() | nil,
          oauth_token: String.t() | nil,
          previous_oauth_token: String.t() | nil,
          event_status: atom(),
          external_calendar_read_list: [String.t()] | nil,
          external_calendar_rw_id: String.t() | nil
        }

  @fields ~w(external_calendar_rw_id external_calendar_read_list)a
  @clear_fields Enum.into([:oauth_token | @fields], %{}, &{&1, nil})
  @token_fields ~w(account_id event_status oauth_token)a

  @spec set_nylas_token!(t(), map()) :: t()
  def set_nylas_token!(%__MODULE__{} = nylas_detail, attrs) do
    nylas_detail
    |> cast(attrs, @token_fields)
    |> validate_required(@token_fields)
    |> Repo.update!()
  end

  @spec clear_nylas_token!(t()) :: t()
  def clear_nylas_token!(%__MODULE__{oauth_token: oauth_token} = nylas_detail) do
    nylas_detail
    |> change(Map.put(@clear_fields, :previous_oauth_token, oauth_token))
    |> Repo.update!()
  end

  @spec set_nylas_calendars!(t(), map()) :: t()
  def set_nylas_calendars!(%__MODULE__{user_id: user_id} = nylas_detail, calendars) do
    changeset = cast(nylas_detail, calendars, @fields)

    case nylas_detail do
      %{event_status: :in_progress} ->
        Multi.new()
        |> Multi.update(:nylas_detail, changeset)
        |> Oban.insert(
          :move_events,
          CalendarEvent.new(%{type: "move", user_id: user_id})
        )
        |> Repo.transaction()
        |> then(fn {:ok, %{nylas_detail: nylas_detail}} -> nylas_detail end)

      _ ->
        changeset
        |> event_status_change()
        |> Repo.update!()
    end
  end

  @spec reset_event_status!(t()) :: t()
  def reset_event_status!(%__MODULE__{} = nylas_detail) do
    nylas_detail
    |> change()
    |> event_status_change()
    |> Repo.update!()
  end

  defp event_status_change(changeset) do
    changeset
    |> put_change(:event_status, :moved)
    |> put_change(:previous_oauth_token, nil)
  end
end
