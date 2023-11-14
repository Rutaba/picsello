defmodule Picsello.Repo.Migrations.AddCampaignIdToClientMessageAttachmentsTable do
  use Ecto.Migration

  def change do
    alter table(:client_message_attachments) do
      add(:campaign_id, references(:campaigns, column: :id))
      modify(:client_message_id, :integer, null: true, from: {:integer, [null: false]})
    end
  end
end
