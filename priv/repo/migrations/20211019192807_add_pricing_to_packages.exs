defmodule Picsello.Repo.Migrations.AddPricingToPackages do
  use Ecto.Migration

  def up do
    rename(table(:packages), :price, to: :base_price)

    alter table(:packages) do
      add(:gallery_credit, :integer)
      add(:download_each_price, :integer)
      add(:download_count, :integer)
    end

    execute("""
      update packages set download_each_price = 0, download_count = 0;
    """)

    alter table(:packages) do
      modify(:download_each_price, :integer, null: false)
      modify(:download_count, :integer, null: false)
    end
  end

  def down do
    rename(table(:packages), :base_price, to: :price)

    alter table(:packages) do
      remove(:gallery_credit, :integer)
      remove(:download_each_price, :integer)
      remove(:download_count, :integer)
    end
  end
end
