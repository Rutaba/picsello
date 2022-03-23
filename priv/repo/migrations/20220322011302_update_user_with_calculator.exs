defmodule Picsello.Repo.Migrations.UpdateUserWithCalculator do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:pricing_calculator, :map, null: false, default: fragment("'[]'::jsonb"))
    end
  end
end
