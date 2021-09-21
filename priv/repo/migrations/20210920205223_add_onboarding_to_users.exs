defmodule Picsello.Repo.Migrations.AddOnboardingToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:onboarding, :map, null: false, default: %{})
    end
  end
end
