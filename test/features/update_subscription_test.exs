defmodule Picsello.SubscriptionChangesTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Accounts.User}

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    user = user |> User.assign_stripe_customer_changeset("cus_123") |> Repo.update!()
    plan = insert(:subscription_plan)

    [plan: plan, user: user]
  end

  feature "when subscription is in trial", %{session: session, user: user, plan: plan} do
    insert(:subscription_event,
      user: user,
      subscription_plan: plan,
      current_period_end: DateTime.utc_now() |> DateTime.add(60 * 60 * 24 + 60),
      status: "trialing"
    )

    session
    |> click(link("Settings"))
    |> assert_text("Current Plan")
    |> assert_text("1 day left in your trial")
    |> assert_text("$50/month")
  end

  feature "when subscription will cancel", %{session: session, user: user, plan: plan} do
    insert(:subscription_event,
      user: user,
      subscription_plan: plan,
      cancel_at: DateTime.utc_now() |> DateTime.add(60 * 60 * 24 + 60),
      status: "active"
    )

    session
    |> click(link("Settings"))
    |> assert_text("Subscribe now")
    |> assert_text("1 day left until your subscription ends")
    |> assert_text("$50/month")
  end

  feature "when subscription is active", %{session: session, user: user, plan: plan} do
    insert(:subscription_event, user: user, subscription_plan: plan, status: "active")

    session
    |> click(link("Settings"))
    |> assert_text("Current Plan")
    |> assert_text("$50/month")
  end

  feature "when subscription is canceled", %{session: session, user: user, plan: plan} do
    insert(:subscription_event, user: user, subscription_plan: plan, status: "canceled")

    yearly_plan =
      insert(:subscription_plan,
        recurring_interval: "year",
        stripe_price_id: "price_987",
        price: 50_000
      )

    test_pid = self()

    Picsello.MockPayments
    |> Mox.stub(:create_session, fn params, opts ->
      send(
        test_pid,
        {:checkout_linked, opts |> Enum.into(params)}
      )

      {:ok, "https://example.com/stripe-checkout"}
    end)
    |> Mox.stub(:retrieve_session, fn "{CHECKOUT_SESSION_ID}", _opts ->
      {:ok, %Stripe.Session{subscription: "sub_123"}}
    end)
    |> Mox.stub(:retrieve_subscription, fn "sub_123", _opts ->
      {:ok,
       %Stripe.Subscription{
         id: "s1",
         status: "active",
         current_period_start: DateTime.utc_now() |> DateTime.to_unix(),
         current_period_end: DateTime.utc_now() |> DateTime.add(100) |> DateTime.to_unix(),
         plan: %{id: yearly_plan.stripe_price_id},
         customer: "cus_123"
       }}
    end)

    session
    |> click(link("Settings"))
    |> assert_path("/home")
    |> assert_text("Your plan has expired")
    |> click(button("Select this plan", count: 2, at: 1))

    assert_receive {:checkout_linked, %{success_url: stripe_success_url}}

    session
    |> visit(stripe_success_url)
    |> assert_text("You have subscribed to Picsello")
    |> click(button("Close"))
    |> click(link("Settings"))
    |> assert_text("Current Plan")
    |> assert_text("$500/year")
  end

  feature "user goes to billing portal", %{session: session, user: user, plan: plan} do
    insert(:subscription_event, user: user, subscription_plan: plan, status: "active")

    test_pid = self()

    Mox.stub(Picsello.MockPayments, :create_billing_portal_session, fn params ->
      send(
        test_pid,
        {:portal_session_created, params}
      )

      {:ok,
       %{
         url:
           PicselloWeb.Endpoint.struct_url()
           |> Map.put(:fragment, "stripe-billing-portal")
           |> URI.to_string()
       }}
    end)

    session
    |> click(link("Settings"))
    |> click(button("Open Billing Portal"))
    |> assert_url_contains("stripe-billing-portal")

    return_url = Routes.user_settings_url(PicselloWeb.Endpoint, :edit)

    assert_receive {:portal_session_created, %{customer: "cus_123", return_url: ^return_url}}
  end
end
