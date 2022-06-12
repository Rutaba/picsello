defmodule Picsello.Repo.Migrations.AddComingSoonColumnToCategories do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :coming_soon, :boolean, null: false, default: false
    end

    execute("update categories set coming_soon = false", "")
  end
end
