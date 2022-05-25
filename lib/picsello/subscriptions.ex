defmodule Picsello.Subscriptions do
  @moduledoc false
  alias Picsello.{
    Repo,
    SubscriptionPlan,
    SubscriptionEvent,
    Payments,
    Subscription,
    Accounts.User
  }

  import Ecto.Query
  require Logger

  def sync_subscription_plans() do
    {:ok, %{data: prices}} = Payments.list_prices(%{active: true})

    for price <- Enum.filter(prices, &(&1.type == "recurring")) do
      %{
        stripe_price_id: price.id,
        price: price.unit_amount,
        recurring_interval: price.recurring.interval,
        # setting active to false to avoid conflicting prices on sync
        active: false
      }
      |> SubscriptionPlan.changeset()
      |> Repo.insert!(
        conflict_target: [:stripe_price_id],
        on_conflict: {:replace, [:price, :recurring_interval, :updated_at]}
      )
    end
  end

  def sync_trialing_subscriptions() do
    {:ok, %{data: subscriptions}} = Stripe.Subscription.list(%{status: "trialing"})

    for subscription <- subscriptions do
      {:ok, customer} = Stripe.Customer.retrieve(subscription |> Map.get(:customer))
      user = Repo.get_by(User, email: customer.email)

      if user && User.onboarded?(user) && !user.stripe_customer_id do
        user
        |> User.assign_stripe_customer_changeset(customer.id)
        |> Repo.update!()

        {:ok, _} = handle_stripe_subscription(subscription)
      end
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
    Repo.all(from(s in SubscriptionPlan, where: s.active == true, order_by: s.price))
  end

  def all_subscription_plans() do
    Repo.all(from(s in SubscriptionPlan, order_by: s.price))
  end

  def get_subscription_plan(recurring_interval \\ "month"),
    do: Repo.get_by!(SubscriptionPlan, %{recurring_interval: recurring_interval, active: true})

  def checkout_link(%User{} = user, recurring_interval, opts) do
    subscription_plan = get_subscription_plan(recurring_interval)

    cancel_url = opts |> Keyword.get(:cancel_url)
    success_url = opts |> Keyword.get(:success_url)
    trial_days = opts |> Keyword.get(:trial_days)

    subscription_data =
      if trial_days, do: %{subscription_data: %{trial_period_days: trial_days}}, else: %{}

    stripe_params =
      %{
        cancel_url: cancel_url,
        success_url: success_url,
        customer: user_customer_id(user),
        mode: "subscription",
        line_items: [
          %{
            quantity: 1,
            price: subscription_plan.stripe_price_id
          }
        ]
      }
      |> Map.merge(subscription_data)

    case Payments.create_session(stripe_params, opts) do
      {:ok, %{url: url}} -> {:ok, url}
      err -> err
    end
  end

  def handle_stripe_subscription(%Stripe.Subscription{} = subscription) do
    with %SubscriptionPlan{id: subscription_plan_id} <-
           Repo.get_by(SubscriptionPlan, stripe_price_id: subscription.plan.id),
         %User{id: user_id} <-
           Repo.get_by(User, stripe_customer_id: subscription.customer) do
      %{
        user_id: user_id,
        subscription_plan_id: subscription_plan_id,
        status: subscription.status,
        stripe_subscription_id: subscription.id,
        cancel_at: subscription.cancel_at |> to_datetime,
        current_period_start: subscription.current_period_start |> to_datetime,
        current_period_end: subscription.current_period_end |> to_datetime
      }
      |> SubscriptionEvent.create_changeset()
      |> Repo.insert()
    else
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end

  def handle_subscription_by_session_id(session_id) do
    with {:ok, session} <-
           Payments.retrieve_session(session_id, []),
         {:ok, subscription} <-
           Payments.retrieve_subscription(session.subscription, []),
         {:ok, _} <- handle_stripe_subscription(subscription) do
      :ok
    else
      e ->
        Logger.warning("no match when retrieving stripe session: #{inspect(e)}")
        e
    end
  end

  def billing_portal_link(%User{stripe_customer_id: customer_id}, return_url) do
    case Payments.create_billing_portal_session(%{customer: customer_id, return_url: return_url}) do
      {:ok, session} -> {:ok, session.url}
      error -> error
    end
  end

  def ensure_active_subscription!(%User{} = user) do
    if Picsello.Subscriptions.subscription_expired?(user) do
      raise Ecto.NoResultsError, queryable: Picsello.Organization
    end
  end

  def subscription_content(%{recurring_interval: recurring_interval, price: price}) do
    price = price |> Money.to_string(fractional_unit: false)

    %{
      length: 30,
      title_prefix: "Start your 30-day free trial",
      description_prefix:
        "After 30 days, your subscription will be #{price}/#{recurring_interval}",
      success_prefix: "Your 30-day free trial",
      onboarding_offer_prefix:
        "Grow your photography business with Picsello—1 month free at signup and you secure the Founder Rate of",
      onboarding_offer: "#{price} a #{recurring_interval}"
    }
  end

  defp user_customer_id(%User{stripe_customer_id: nil} = user) do
    params = %{name: user.name, email: user.email}

    with {:ok, %{id: customer_id}} <- Payments.create_customer(params, []),
         {:ok, user} <-
           user
           |> User.assign_stripe_customer_changeset(customer_id)
           |> Repo.update() do
      user.stripe_customer_id
    else
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  defp user_customer_id(%User{stripe_customer_id: customer_id}), do: customer_id

  defp to_datetime(nil), do: nil
  defp to_datetime(unix_date), do: DateTime.from_unix!(unix_date)
end
