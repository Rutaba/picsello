defmodule Picsello.Repo.Migrations.OrganizationCardsAllowNull do
  use Ecto.Migration

  def change do
    alter table(:organization_cards) do
      modify(:organization_id, :integer, null: true, from: :organization_id)
    end
  end
end
