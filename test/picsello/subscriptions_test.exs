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
               recurring: %{interval: "month"},
               active: true
             },
             %Stripe.Price{
               id: "p2",
               unit_amount: 200,
               type: "recurring",
               recurring: %{interval: "month"},
               active: false
             },
             %Stripe.Price{
               id: "p3",
               unit_amount: 5_000,
               type: "recurring",
               recurring: %{interval: "year"},
               active: true
             },
             %Stripe.Price{
               id: "p4",
               unit_amount: 50_000,
               type: "one_time",
               active: false
             }
           ]
         }}
      end)

      Subscriptions.sync_subscription_plans()

      assert [] = Subscriptions.subscription_plans()

      assert [
               %SubscriptionPlan{
                 active: false,
                 price: %Money{amount: 200, currency: :USD},
                 recurring_interval: "month",
                 stripe_price_id: "p2"
               },
               %SubscriptionPlan{
                 active: false,
                 price: %Money{amount: 500, currency: :USD},
                 recurring_interval: "month",
                 stripe_price_id: "p1"
               },
               %SubscriptionPlan{
                 active: false,
                 price: %Money{amount: 5000, currency: :USD},
                 recurring_interval: "year",
                 stripe_price_id: "p3"
               }
             ] = Subscriptions.all_subscription_plans()
    end
  end
end
