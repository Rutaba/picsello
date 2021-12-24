defmodule Picsello.Repo.Migrations.CreateCampaigns do
  use Ecto.Migration

  def change do
    create table(:campaigns) do
      add(:subject, :text, null: false)
      add(:body_text, :text, null: false)
      add(:body_html, :text, null: false)
      add(:segment_type, :text, null: false)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(:campaigns, [:organization_id]))
  end
end
