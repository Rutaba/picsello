defmodule Picsello.Subscriptions do
  @moduledoc false
  alias Picsello.{Repo, SubscriptionPlan, Payments, Subscription, Accounts.User}
  import Ecto.Query

  def monthly_subscription_plan() do
    Repo.get_by!(SubscriptionPlan, recurring_interval: "month")
  end

  def subscription_plan_by_id(id) do
    Repo.get!(SubscriptionPlan, id)
  end

  def sync_subscription_plans() do
    {:ok, %{data: prices}} = Payments.list_prices(%{active: true})

    for price <- prices do
      %{
        stripe_price_id: price.id,
        price: price.unit_amount,
        recurring_interval: price.recurring.interval
      }
      |> SubscriptionPlan.changeset()
      |> Repo.insert!(
        conflict_target: [:stripe_price_id],
        on_conflict: {:replace, [:price, :recurring_interval, :updated_at]}
      )
    end
  end

  def next_payment?(%Subscription{} = subscription),
    do: subscription.active && !subscription.cancel_at

  def monthly?(%Subscription{recurring_interval: recurring_interval}),
    do: recurring_interval == "month"

  def subscription_expired?(%User{subscription: %Ecto.Association.NotLoaded{}} = user),
    do: user |> Repo.preload(:subscription) |> subscription_expired?()

  def subscription_expired?(%User{subscription: subscription}),
    do: subscription && !subscription.active

  def subscription_plans() do
    Repo.all(from(s in SubscriptionPlan, order_by: s.price))
  end
end
