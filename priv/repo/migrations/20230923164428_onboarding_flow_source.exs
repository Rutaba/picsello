defmodule Picsello.Repo.Migrations.OnboardingFlowSource do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:onboarding_flow_source, {:array, :string}, null: false, default: [])
    end
  end
end
