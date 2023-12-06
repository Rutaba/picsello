defmodule Picsello.SubscriptionPromotionCode do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscription_promotion_codes" do
    field :code, :string
    field :stripe_promotion_code_id, :string
    field :percent_off, :decimal
    field :amount_off, :integer
    field :currency, :string

    timestamps()
  end

  def changeset(subscription_promotion_code \\ %__MODULE__{}, attrs) do
    subscription_promotion_code
    |> cast(attrs, [:code, :stripe_promotion_code_id, :percent_off, :amount_off, :currency])
    |> validate_required([:code, :stripe_promotion_code_id])
  end
end
