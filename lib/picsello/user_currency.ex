defmodule Picsello.UserCurrency do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @default_currency "USD"

  schema "user_currencies" do
    field :previous_currency, :string, default: @default_currency
    field :exchange_rate, :float, default: 1.00

    belongs_to :organization, Picsello.Organization

    belongs_to(:user_currency, Picsello.Currency,
      references: :code,
      type: :string,
      foreign_key: :currency
    )

    timestamps()
  end

  def currency_changeset(user_currency \\ %__MODULE__{}, attrs) do
    user_currency
    |> cast(attrs, [:currency, :previous_currency, :exchange_rate, :organization_id])
    |> validate_required([:previous_currency])
    |> validate_required([:currency])
    |> validate_required([:exchange_rate])
  end
end
