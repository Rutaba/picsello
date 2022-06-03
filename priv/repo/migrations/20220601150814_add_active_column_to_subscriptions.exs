defmodule Picsello.Repo.Migrations.AddActiveColumnToSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:subscription_plans) do
      add :active, :boolean, null: false, default: false
    end

    execute("update subscription_plans set active = true", "")
  end
end
