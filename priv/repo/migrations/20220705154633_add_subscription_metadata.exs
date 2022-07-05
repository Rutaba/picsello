defmodule Picsello.Repo.Migrations.AddSubscriptionMetadata do
  use Ecto.Migration

  def change do
    create table(:subscription_plans_metadata) do
      add(:code, :string, null: false)
      add(:trial_length, :integer, null: false)
      add(:active, :boolean, null: false, default: false)
      add(:signup_title, :string, null: false)
      add(:signup_description, :string, null: false)
      add(:onboarding_title, :string, null: false)
      add(:onboarding_description, :string, null: false)
      add(:success_title, :string, null: false)

      timestamps()
    end
  end
end
