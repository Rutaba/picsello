defmodule Picsello.Repo.Migrations.AddUniqueConstraintToUserCurrencies do
  use Ecto.Migration

  def change do
    create_if_not_exists(unique_index(:user_currencies, [:organization_id]))
  end
end
