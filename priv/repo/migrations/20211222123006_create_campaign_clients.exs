defmodule Picsello.Repo.Migrations.CreateCampaignClients do
  use Ecto.Migration

  def change do
    create table(:campaign_clients) do
      add(:client_id, references(:clients, on_delete: :nothing), null: false)
      add(:campaign_id, references(:campaigns, on_delete: :nothing), null: false)
      add(:delivered_at, :utc_datetime)

      timestamps()
    end

    create(index(:campaign_clients, [:client_id, :campaign_id], unique: true))
  end
end
