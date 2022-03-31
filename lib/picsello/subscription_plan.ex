defmodule Picsello.SubscriptionPlan do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @recurring_intervals ["month", "year"]

  schema "subscription_plans" do
    field :price, Money.Ecto.Amount.Type
    field :stripe_price_id, :string
    field :recurring_interval, :string

    timestamps()
  end

  @doc false
  def changeset(subscription_plan \\ %__MODULE__{}, attrs) do
    subscription_plan
    |> cast(attrs, [:stripe_price_id, :price, :recurring_interval])
    |> validate_required([:stripe_price_id, :price, :recurring_interval])
    |> validate_inclusion(:recurring_interval, @recurring_intervals)
  end
end
