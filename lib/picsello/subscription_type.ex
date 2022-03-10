defmodule Picsello.SubscriptionType do
  use Ecto.Schema
  import Ecto.Changeset

  @recurring_intervals ["month", "year"]

  schema "subscription_types" do
    field :price, :integer
    field :stripe_price_id, :string
    field :recurring_interval, :string

    timestamps()
  end

  @doc false
  def changeset(subscription_type \\ %__MODULE__{}, attrs) do
    subscription_type
    |> cast(attrs, [:stripe_price_id, :price, :recurring_interval])
    |> validate_required([:stripe_price_id, :price, :recurring_interval])
    |> validate_inclusion(:recurring_interval, @recurring_intervals)
  end
end
