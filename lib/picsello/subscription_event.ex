defmodule Picsello.SubscriptionEvent do
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Accounts.User, SubscriptionType}

  schema "subscription_events" do
    field :cancel_at, :utc_datetime
    field :current_period_end, :utc_datetime
    field :current_period_start, :utc_datetime
    field :status, :string
    field :stripe_subscription_id, :string
    belongs_to :subscription_type, SubscriptionType
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :status,
      :stripe_subscription_id,
      :current_period_start,
      :current_period_end,
      :user_id,
      :subscription_type_id,
      :cancel_at
    ])
    |> validate_required([
      :status,
      :stripe_subscription_id,
      :current_period_start,
      :user_id,
      :subscription_type_id,
      :current_period_end
    ])
  end
end
