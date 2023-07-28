defmodule Picsello.NylasDetail do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Repo, Accounts.User}

  schema "nylas_details" do
    field :oauth_token, :string
    field :previous_oauth_token, :string
    field :account_id, :string
    field :previous_account_id, :string
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
          previous_account_id: String.t() | nil,
          external_calendar_read_list: [String.t()] | nil,
          external_calendar_rw_id: String.t() | nil
        }

  @spec set_nylas_token!(t(), String.t()) :: t()
  def set_nylas_token!(%__MODULE__{} = nylas_detail, token) do
    nylas_detail
    |> change(%{oauth_token: token})
    |> Repo.update!()
  end

  @spec clear_nylas_token!(t()) :: t()
  def clear_nylas_token!(%__MODULE__{oauth_token: oauth_token} = nylas_detail) do
    nylas_detail
    |> change(%{
      oauth_token: nil,
      account_id: nil,
      previous_oauth_token: oauth_token,
      external_calendar_rw_id: nil,
      external_calendar_read_list: []
    })
    |> Repo.update!()
  end

  @spec set_nylas_calendars!(
          t(),
          :invalid | map()
        ) :: t()
  def set_nylas_calendars!(%__MODULE__{} = nylas_detail, calendars) do
    nylas_detail
    |> cast(calendars, [
      :external_calendar_rw_id,
      :external_calendar_read_list
    ])
    |> Repo.update!()
  end
end
