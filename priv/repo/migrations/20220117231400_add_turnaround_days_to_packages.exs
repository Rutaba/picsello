defmodule Picsello.Repo.Migrations.AddTurnaroundDaysToPackages do
  use Ecto.Migration

  def up do
    alter table(:packages) do
      add(:turnaround_weeks, :integer)
    end

    alter table(:package_base_prices) do
      add(:turnaround_weeks, :integer)
    end

    execute("update packages set turnaround_weeks = 3")
    execute("update package_base_prices set turnaround_weeks = 3")

    alter table(:packages) do
      modify(:turnaround_weeks, :integer, null: false)
    end

    alter table(:package_base_prices) do
      modify(:turnaround_weeks, :integer, null: false)
    end
  end

  def down do
    alter table(:packages) do
      remove(:turnaround_weeks)
    end

    alter table(:package_base_prices) do
      remove(:turnaround_weeks)
    end
  end
end
