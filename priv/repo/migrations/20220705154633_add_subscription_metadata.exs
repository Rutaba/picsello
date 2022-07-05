defmodule Picsello.Repo.Migrations.AddSubscriptionMetadata do
  use Ecto.Migration

  def change do
    create table(:subscription_plans_metadata) do
      add(:code, :string, null: false)
      add(:trial_length, :integer, null: false)
      add(:active, :boolean, null: false, default: false)
      add(:content, :map, default: fragment("'{}'::jsonb"))

      timestamps()
    end
  end
end
