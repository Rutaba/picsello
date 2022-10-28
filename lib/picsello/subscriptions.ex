defmodule Picsello.Subscriptions do
  @moduledoc false
  alias Picsello.{
    Repo,
    SubscriptionPlan,
    SubscriptionEvent,
    Payments,
    Subscription,
    Accounts.User,
    SubscriptionPlansMetadata
  }

  import PicselloWeb.Helpers, only: [days_distance: 1]
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

  def subscription_ending_soon_info(nil), do: %{hidden?: true}

  def subscription_ending_soon_info(%User{subscription: %Ecto.Association.NotLoaded{}} = user),
    do: user |> Repo.preload(:subscription) |> subscription_ending_soon_info()

  def subscription_ending_soon_info(%User{subscription: subscription}) do
    case subscription do
      %{current_period_end: current_period_end, cancel_at: cancel_at} when cancel_at != nil ->
        days_left = days_distance(current_period_end)

        %{
          hidden?: calculate_days_left_boolean(days_left, 7),
          hidden_30_days?: calculate_days_left_boolean(days_left, 30),
          days_left: days_left |> Kernel.max(0),
          subscription_end_at: DateTime.to_date(current_period_end)
        }

      _ ->
        %{hidden?: true, hidden_30_days?: true}
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

  def subscription_payment_method?(%User{stripe_customer_id: stripe_customer_id}) do
    case stripe_customer_id do
      nil -> false
      _ -> Payments.retrieve_customer(stripe_customer_id) |> check_card_source()
    end
  end

  def subscription_payment_method?(_), do: false

  def subscription_plans() do
    Repo.all(from(s in SubscriptionPlan, where: s.active == true, order_by: s.price))
  end

  def all_subscription_plans() do
    Repo.all(from(s in SubscriptionPlan, order_by: s.price))
  end

  def get_subscription_plan(recurring_interval \\ "month"),
    do: Repo.get_by!(SubscriptionPlan, %{recurring_interval: recurring_interval, active: true})

  def subscription_base(%User{} = user, recurring_interval, opts) do
    subscription_plan = get_subscription_plan(recurring_interval)

    trial_days = opts |> Keyword.get(:trial_days)

    stripe_params = %{
      customer: user_customer_id(user),
      items: [
        %{
          quantity: 1,
          price: subscription_plan.stripe_price_id
        }
      ],
      cancel_at_period_end: true,
      trial_period_days: trial_days
    }

    case Payments.create_subscription(stripe_params) do
      {:ok, subscription} -> subscription
      err -> err
    end
  end

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

  def user_customer_id(%User{stripe_customer_id: nil} = user) do
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

  def user_customer_id(%User{stripe_customer_id: customer_id}), do: customer_id

  def all_subscription_plans_metadata(), do: Repo.all(from(s in SubscriptionPlansMetadata))

  def get_subscription_plan_metadata(code), do: subscription_plan_metadata(code)
  def get_subscription_plan_metadata(), do: subscription_plan_metadata()

  defp subscription_plan_metadata(%Picsello.SubscriptionPlansMetadata{} = query), do: query

  defp subscription_plan_metadata(nil),
    do: subscription_plan_metadata_default()

  defp subscription_plan_metadata(code),
    do:
      Repo.get_by(SubscriptionPlansMetadata, code: code, active: true)
      |> subscription_plan_metadata()

  defp subscription_plan_metadata(),
    do: subscription_plan_metadata_default()

  defp subscription_plan_metadata_default(),
    do: %Picsello.SubscriptionPlansMetadata{
      trial_length: 30,
      onboarding_description:
        "Your 30-day free trial lets you explore and use all of our amazing features. To get started we’ll ask you to enter your credit card to keep your account secure and for us to focus the team on those who are really interested in Picsello.",
      onboarding_title: "Start your 30-day free trial",
      signup_description: "Start your free trial",
      signup_title: "Get started with your free 30-day free trial today",
      success_title: "Your 30-day free trial has started!"
    }

  defp to_datetime(nil), do: nil
  defp to_datetime(unix_date), do: DateTime.from_unix!(unix_date)

  defp check_card_source(
         {:ok,
          %Stripe.Customer{invoice_settings: %{default_payment_method: default_payment_method}}}
       ) do
    case default_payment_method do
      nil -> false
      _ -> true
    end
  end

  defp calculate_days_left_boolean(days_left, max) do
    days_left > max || days_left < 0
  end
end
