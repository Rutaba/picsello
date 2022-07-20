defmodule Picsello.Repo.Migrations.ModifySubscriptionMetadata do
  use Ecto.Migration

  def change do
    alter table(:subscription_plans_metadata) do
      modify(:signup_description, :text, from: :string)
      modify(:onboarding_description, :text, from: :string)
    end
  end
end
