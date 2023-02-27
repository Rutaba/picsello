defmodule Picsello.Repo.Migrations.IsTestUserForAnalytics do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:is_test_account, :boolean, null: false, default: false)
    end
  end
end
