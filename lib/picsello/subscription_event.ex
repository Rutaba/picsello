defmodule Picsello.SubscriptionEvent do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Accounts.User, SubscriptionPlan}

  schema "subscription_events" do
    field :cancel_at, :utc_datetime
    field :current_period_end, :utc_datetime
    field :current_period_start, :utc_datetime
    field :status, :string
    field :stripe_subscription_id, :string
    belongs_to :subscription_plan, SubscriptionPlan
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
      :subscription_plan_id,
      :cancel_at
    ])
    |> validate_required([
      :status,
      :stripe_subscription_id,
      :current_period_start,
      :user_id,
      :subscription_plan_id,
      :current_period_end
    ])
  end
end
