defmodule Picsello.Repo.Migrations.AddSessionIdToIntents do
  use Ecto.Migration

  def up do
    execute("alter table gallery_order_intents add column stripe_session_id text unique
      ")

    execute(
      "update gallery_order_intents set stripe_session_id = 'UNKNOWN - intent:' || stripe_id"
    )

    execute("alter table gallery_order_intents rename stripe_id to stripe_payment_intent_id")

    execute("alter table gallery_order_intents alter stripe_session_id set not null")

    execute("drop index gallery_order_intents_order_id_idx")

    execute(
      "create unique index gallery_order_intents_uncanceled_order_id on gallery_order_intents (order_id) where status != 'canceled'"
    )
  end

  def down do
    execute("drop index gallery_order_intents_uncanceled_order_id")

    execute("alter table gallery_order_intents rename stripe_payment_intent_id to stripe_id")

    execute("delete from gallery_order_intents where status = 'canceled'")

    execute("""
      alter table gallery_order_intents drop stripe_session_id
    """)

    execute(
      "create unique index gallery_order_intents_order_id_idx on gallery_order_intents (order_id)"
    )
  end
end
