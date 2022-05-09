defmodule Picsello.Repo.Migrations.AddShippingToCategories do
  use Ecto.Migration

  def up do
    execute("""
    alter table categories add column shipping_base_charge integer not null default 0, add column shipping_upcharge decimal not null default 0
    """)

    execute("""
    update categories set shipping_base_charge = 595, shipping_upcharge = 0.06 where whcc_name = 'Loose Prints'
    """)

    execute("""
    update categories set shipping_base_charge = 985, shipping_upcharge = 0.09 where whcc_name != 'Loose Prints'
    """)
  end

  def down do
    execute("""
    alter table categories drop column shipping_base_charge, drop column shipping_upcharge
    """)
  end
end
