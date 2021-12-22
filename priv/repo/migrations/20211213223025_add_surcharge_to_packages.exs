defmodule Picsello.Repo.Migrations.AddSurchargeToPackages do
  use Ecto.Migration

  def change do
    alter table("packages") do
      add(:base_multiplier, :decimal, default: 1.0)
    end
  end
end
