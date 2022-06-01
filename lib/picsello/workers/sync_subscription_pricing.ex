defmodule Picsello.Workers.SyncSubscriptionPricing do
  @moduledoc false
  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  @impl Oban.Worker
  def perform(_) do
    Picsello.Subscriptions.sync_subscription_plans()

    :ok
  end
end
