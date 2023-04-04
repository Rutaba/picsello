defmodule Picsello.SubscriptionPromotionCode do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscription_promotion_codes" do
    field :code, :string
    field :stripe_promotion_code_id, :string
    field :percent_off, :decimal

    timestamps()
  end

  def changeset(subscription_promotion_code \\ %__MODULE__{}, attrs) do
    subscription_promotion_code
    |> cast(attrs, [:code, :stripe_promotion_code_id, :percent_off])
    |> validate_required([:code, :stripe_promotion_code_id, :percent_off])
  end
end
