defmodule Picsello.Repo.Migrations.ModifySubscriptionMetadata do
  use Ecto.Migration

  def change do
    alter table(:subscription_plans_metadata) do
      modify(:signup_description, :text)
      modify(:onboarding_description, :text)
    end
  end
end
