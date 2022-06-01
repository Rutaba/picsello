defmodule Picsello.Repo.Migrations.AddActiveColumnToSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:subscription_plans) do
      add :active, :boolean, null: false, default: true
    end
  end
end
