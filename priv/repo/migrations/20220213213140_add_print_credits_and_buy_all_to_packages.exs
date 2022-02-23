defmodule Picsello.Repo.Migrations.AddPrintCreditsToPackages do
  use Ecto.Migration

  def change do
    alter table("packages") do
      add(:print_credits, :integer)
      add(:buy_all, :integer)
    end
  end
end
