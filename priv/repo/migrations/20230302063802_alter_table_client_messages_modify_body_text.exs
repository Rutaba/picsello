defmodule Picsello.Repo.Migrations.AlterTableClientMessagesModifyBodyText do
  use Ecto.Migration

  @table :client_messages
  def up do
    alter table(@table) do
      modify(:body_text, :text, null: true)
    end
  end

  def down do
    alter table(@table) do
      modify(:body_text, :text, null: false)
    end
  end
end
