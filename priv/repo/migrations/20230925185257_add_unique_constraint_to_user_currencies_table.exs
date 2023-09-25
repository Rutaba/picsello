defmodule Picsello.Repo.Migrations.AddUniqueConstraintToUserCurrenciesTable do
  use Ecto.Migration

  def change do
    create(unique_index(:user_currencies, [:organization_id]))
  end
end
