defmodule Picsello.Repo.Migrations.AddDefaultMarkupToCategories do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add(:default_markup, :decimal, null: false, default: 2.0)
    end
  end
end
