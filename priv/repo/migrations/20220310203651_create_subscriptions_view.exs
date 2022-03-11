defmodule Picsello.Repo.Migrations.CreateSubscriptionsView do
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
      st.price,
      st.recurring_interval
    from subscription_events se
    join subscription_types st on st.id = se.subscription_type_id
    order by se.user_id, se.current_period_start desc, se.id desc
  )
  """

  def change do
    execute(@new_view, @old_view)
  end
end
