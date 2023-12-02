defmodule Picsello.Repo.Migrations.AddHoliday do
  use Ecto.Migration

  alias Picsello.{AdminGlobalSetting, Repo}
  import Ecto.Query

  def up do
    execute("""
      INSERT INTO admin_global_settings VALUES (#{8}, 'Three month Code', 'Coupon code for Three month deal', 'three_month', 'THREEMONTHDEAL', 'active', now(), now());
    """)

    alter table(:subscription_promotion_codes) do
      modify(:percent_off, :decimal, null: true)
      add(:amount_off, :integer)
      add(:currency, :string)
    end
  end

  def down do
    remove_three_month_code_from_admin_global_settings()

    alter table(:subscription_promotion_codes) do
      remove(:amount_off, :integer)
      remove(:currency, :string)
      modify(:percent_off, :decimal, null: false)
    end
  end

  defp remove_three_month_code_from_admin_global_settings(),
    do:
      Repo.delete(
        from(ags in AdminGlobalSetting, where: ags.slug == "three_month")
        |> Repo.one()
      )
end
