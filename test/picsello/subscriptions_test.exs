defmodule Picsello.SubscriptionsTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Subscriptions, SubscriptionPlan}

  describe "sync_subscription_plans" do
    test "returns a link when called with a user with no account" do
      Mox.stub(Picsello.MockPayments, :list_prices, fn _ ->
        {:ok,
         %{
           data: [
             %Stripe.Price{
               id: "p1",
               unit_amount: 500,
               type: "recurring",
               recurring: %{interval: "month"}
             },
             %Stripe.Price{
               id: "p2",
               unit_amount: 5_000,
               type: "recurring",
               recurring: %{interval: "year"}
             },
             %Stripe.Price{
               id: "p3",
               unit_amount: 50_000,
               type: "one_time"
             }
           ]
         }}
      end)

      Subscriptions.sync_subscription_plans()

      assert [
               %SubscriptionPlan{
                 stripe_price_id: "p1",
                 price: %Money{amount: 500, currency: :USD},
                 recurring_interval: "month"
               },
               %SubscriptionPlan{
                 stripe_price_id: "p2",
                 price: %Money{amount: 5_000, currency: :USD},
                 recurring_interval: "year"
               }
             ] = Subscriptions.subscription_plans()
    end
  end
end