defmodule Picsello.Repo.Migrations.SubscriptionPromoCodes do
  use Ecto.Migration

  @old_view """
  drop view subscriptions
  """

  @new_view """
  create or replace view subscriptions as (
    select distinct on (se.user_id) user_id,
      (se.status != 'canceled') as active,
      se.cancel_at,
      se.current_period_end,
      se.current_period_start,
      se.status,
      sp.price,
      sp.recurring_interval,
      se.stripe_subscription_id
    from subscription_events se
    join subscription_plans sp on sp.id = se.subscription_plan_id
    order by se.user_id, se.current_period_start desc, se.id desc
  )
  """

  def change do
    create table(:subscription_promotion_codes) do
      add(:code, :string, null: false)
      add(:stripe_promotion_code_id, :string, null: false)
      add(:percent_off, :decimal, null: false)

      timestamps()
    end

    create(unique_index(:subscription_promotion_codes, ~w[stripe_promotion_code_id]a))

    execute(@new_view, @old_view)
  end
end
