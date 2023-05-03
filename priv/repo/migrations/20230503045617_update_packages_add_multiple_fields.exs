defmodule Picsello.Repo.Migrations.UpdatePackagesAddMultipleFields do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add(:print_credits_include_in_total, :boolean, default: false)
      add(:digitals_include_in_total, :boolean, default: false)
      add(:discount_base_price, :boolean, default: false)
      add(:discount_digitals, :boolean, default: false)
      add(:discount_print_credits, :boolean, default: false)
    end
  end
end
