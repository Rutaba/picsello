defmodule Picsello.SubscriptionChangesTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Accounts.User}

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    user = user |> User.assign_stripe_customer_changeset("cus_123") |> Repo.update!()
    plan = insert(:subscription_plan)

    Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "cus_123", _ ->
      {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
    end)

    [plan: plan, user: user]
  end

  feature "Subscription ending in less than 7 days and subscription is cancelled", %{
    session: session,
    user: user,
    plan: plan
  } do
    current_period_end = DateTime.utc_now() |> DateTime.add(60 * 60 * 24 + 60)

    insert(:subscription_event,
      user: user,
      cancel_at: DateTime.utc_now(),
      subscription_plan: plan,
      current_period_end: current_period_end,
      status: "trialing"
    )

    session
    |> click(link("Settings"))
    |> find(
      testid("subscription-top-banner"),
      &assert_text(&1, "1 day left before your subscription ends")
    )
    |> find(
      testid("subscription-footer"),
      &assert_text(&1, "1 day left until your subscription ends")
    )
    |> assert_has(css("*[role='status']", text: "1 day left until your subscription ends"))
    |> visit("/home")
    |> find(
      testid("attention-item",
        text:
          "You have 1 day left before your subscription ends. You will lose access on #{DateTime.to_date(current_period_end)}"
      ),
      &click(&1, button("Go to acccount settings"))
    )
    |> assert_path("/users/settings")
  end

  feature "Subscription ending in more than 7 days and subscription is cancelled", %{
    session: session,
    user: user,
    plan: plan
  } do
    current_period_end = DateTime.utc_now() |> DateTime.add(8 * 60 * 60 * 24 + 60)

    insert(:subscription_event,
      user: user,
      cancel_at: DateTime.utc_now(),
      subscription_plan: plan,
      current_period_end: current_period_end,
      status: "trialing"
    )

    session
    |> click(link("Settings"))
    |> assert_has(testid("subscription-top-banner", text: "left in your trial", count: 0))
    |> assert_has(testid("subscription-footer", text: "left in your trial", count: 0))
    |> assert_has(css("*[role='status']", text: "8 days left until your subscription ends"))
    |> visit("/home")
    |> assert_has(testid("attention-item", text: "left before your subscription ends", count: 0))
  end

  feature "Subscription ending in less than 7 days and subscription is not cancelled", %{
    session: session,
    user: user,
    plan: plan
  } do
    current_period_end = DateTime.utc_now() |> DateTime.add(60 * 60 * 24 + 60)

    insert(:subscription_event,
      user: user,
      subscription_plan: plan,
      current_period_end: current_period_end,
      status: "trialing"
    )

    session
    |> click(link("Settings"))
    |> assert_has(testid("subscription-top-banner", text: "left in your trial", count: 0))
    |> assert_has(testid("subscription-footer", text: "left in your trial", count: 0))
    |> assert_has(css("*[role='status']", text: "1 day left in your trial"))
    |> visit("/home")
    |> assert_has(testid("attention-item", text: "left before your subscription ends", count: 0))
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
    |> assert_text("$20/month")
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
    |> assert_text("$20/month")
  end

  feature "when subscription is active", %{session: session, user: user, plan: plan} do
    insert(:subscription_event, user: user, subscription_plan: plan, status: "active")

    session
    |> click(link("Settings"))
    |> assert_text("Current Plan")
    |> assert_text("$20/month")
  end

  feature "when subscription is canceled", %{session: session, user: user, plan: plan} do
    insert(:subscription_event, user: user, subscription_plan: plan, status: "canceled")

    yearly_plan =
      insert(:subscription_plan,
        recurring_interval: "year",
        stripe_price_id: "price_987",
        price: 50_000,
        active: true
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
    |> assert_text("Your subscription has expired")
    |> click(button("Select plan", count: 2, at: 1))

    assert_receive {:checkout_linked, %{success_url: stripe_success_url}}

    session
    |> visit(stripe_success_url)
    |> assert_text("You have subscribed to Picsello")
    |> click(button("Close"))
    |> click(link("Settings"))
    |> assert_text("Current Plan")
    |> assert_text("$500/year")
  end

  feature "when subscription is canceled and adds a promo code", %{
    session: session,
    user: user,
    plan: plan
  } do
    insert(:subscription_event, user: user, subscription_plan: plan, status: "canceled")

    yearly_plan =
      insert(:subscription_plan,
        recurring_interval: "year",
        stripe_price_id: "price_987",
        price: 50_000,
        active: true
      )

    insert(:subscription_promotion_codes,
      code: "20OFF",
      stripe_promotion_code_id: "asdf231",
      percent_off: 20.0
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
    |> assert_text("Your subscription has expired")
    |> click(testid("promo-code"))
    |> fill_in(text_field("Applies to monthly or yearly"), with: "FRIENDS20")
    |> assert_text("Applies to monthly or yearly (code doesn't exist)")
    |> fill_in(text_field("Applies to monthly or yearly"), with: "")
    |> assert_text("Applies to monthly or yearly")
    |> fill_in(text_field("Applies to monthly or yearly"), with: "20OFF")
    |> assert_text("Applies to monthly or yearly")
    |> click(testid("promo-code"))
    |> assert_text("Your subscription has expired")
    |> click(button("Select plan", count: 2, at: 1))

    assert_receive {:checkout_linked, %{success_url: stripe_success_url}}

    session
    |> visit(stripe_success_url)
    |> assert_text("You have subscribed to Picsello")
    |> click(button("Close"))
    |> click(link("Settings"))
    |> assert_text("Current Plan")
    |> assert_text("$500/year")
    |> assert_text("20OFF")
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

  feature "user adds a promotion code", %{session: session, user: user, plan: plan} do
    insert(:subscription_event, user: user, subscription_plan: plan, status: "active")

    insert(:subscription_promotion_codes,
      code: "20OFF",
      stripe_promotion_code_id: "asdf231",
      percent_off: 20.0
    )

    Mox.stub(Picsello.MockPayments, :update_subscription, fn _, %{coupon: coupon}, _ ->
      {:ok,
       %Stripe.Subscription{
         id: "sub_123",
         status: "active",
         customer: "cus_123",
         discount: %{
           coupon: %{
             id: coupon
           }
         }
       }}
    end)

    session
    |> click(link("Settings"))
    |> assert_text("Add promo code")
    |> click(testid("promo-code"))
    |> within_modal(fn modal ->
      modal
      |> fill_in(text_field("Add a subscription promo code"), with: "FRIENDS20")
      |> assert_text("(code doesn't exist)")
      |> fill_in(text_field("Add a subscription promo code"), with: "")
      |> fill_in(text_field("Add a subscription promo code"), with: "20OFF")
      |> wait_for_enabled_submit_button()
      |> click(button("Save code"))
    end)
    |> visit("/users/settings")
    |> assert_text("Edit promo code")
    |> assert_text("Current Plan")
    |> assert_text("20OFF")
  end
end
