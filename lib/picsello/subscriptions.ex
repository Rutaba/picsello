defmodule Picsello.Subscriptions do
  alias Picsello.{Repo, SubscriptionType, Payments}

  def monthly_subscription_type() do
    Repo.get_by!(SubscriptionType, recurring_interval: "month")
  end

  def sync_subscription_types() do
    {:ok, %{data: prices}} = Payments.list_prices(%{active: true})

    for price <- prices do
      %{
        stripe_price_id: price.id,
        price: price.unit_amount,
        recurring_interval: price.recurring.interval
      }
      |> SubscriptionType.changeset()
      |> Repo.insert!(
        conflict_target: [:stripe_price_id],
        on_conflict: {:replace, [:price, :recurring_interval, :updated_at]}
      )
    end
  end
end
