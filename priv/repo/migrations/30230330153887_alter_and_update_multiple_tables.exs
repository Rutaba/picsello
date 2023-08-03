defmodule Picsello.Repo.Migrations.AlterAndUpdateMultipleTables do
  use Ecto.Migration

  @packages_table "packages"
  @gallery_orders_table "gallery_orders"
  @payment_schedules_table "payment_schedules"
  @digital_line_items_table "digital_line_items"
  @packages_base_price_table "package_base_prices"
  @global_settings_table "global_settings_galleries"
  @gallery_order_intents_table "gallery_order_intents"
  @gallery_order_invoices_table "gallery_order_invoices"
  @gallery_digital_pricing_table "gallery_digital_pricing"
  @package_payment_schedules_table "package_payment_schedules"

  def up do
    # drop view job_statuses, it will be recreated later after altering dependent fields
    execute("DROP VIEW job_statuses")

    # alter and update tables
    modify_and_update(@packages_table, "download_each_price")
    modify_and_update(@packages_table, "buy_all")
    modify_and_update(@packages_table, "collected_price")
    modify_and_update(@packages_table, "base_price")
    modify_and_update(@packages_table, "print_credits")

    modify_and_update(@payment_schedules_table, "price")

    modify_and_update(@gallery_digital_pricing_table, "download_each_price")
    modify_and_update(@gallery_digital_pricing_table, "buy_all")
    modify_and_update(@gallery_digital_pricing_table, "print_credits")

    modify_and_update(@gallery_orders_table, "bundle_price")

    modify_and_update(@digital_line_items_table, "price")

    modify_and_update(@gallery_order_intents_table, "amount")
    modify_and_update(@gallery_order_intents_table, "amount_capturable")
    modify_and_update(@gallery_order_intents_table, "amount_received")
    modify_and_update(@gallery_order_intents_table, "application_fee_amount")
    modify_and_update(@gallery_order_intents_table, "processing_fee")

    modify_and_update(@gallery_order_invoices_table, "amount_due")
    modify_and_update(@gallery_order_invoices_table, "amount_paid")
    modify_and_update(@gallery_order_invoices_table, "amount_remaining")

    modify_and_update(@packages_base_price_table, "base_price")
    modify_and_update(@packages_base_price_table, "print_credits")
    modify_and_update(@packages_base_price_table, "buy_all")

    modify_and_update(@package_payment_schedules_table, "price")

    modify_and_update(@global_settings_table, "buy_all_price")
    modify_and_update(@global_settings_table, "download_each_price")
  end

  defp modify_and_update(table, field) do
    new_field = "new_" <> field

    execute("ALTER TABLE #{table} ADD COLUMN #{new_field} jsonb")

    execute("""
    UPDATE #{table}
    SET #{new_field} = CASE
    WHEN #{field} IS NOT NULL THEN jsonb_build_object('currency', 'USD', 'amount', #{field})
    ELSE NULL
    END
    """)

    execute("ALTER TABLE #{table} DROP COLUMN #{field}")
    execute("ALTER TABLE #{table} RENAME COLUMN #{new_field} TO #{field}")
  end

  def down do
    # execute("drop view job_statuses")
  end
end
