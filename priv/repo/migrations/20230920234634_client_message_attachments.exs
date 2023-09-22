defmodule Picsello.Repo.Migrations.ClientMessageAttachments do
  use Ecto.Migration
  @table :client_message_attachments

  def up do
    create table(@table) do
      add(:name, :string, null: false)
      add(:url, :string, null: false)
      add(:client_message_id, references(:client_messages, on_delete: :nothing), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(@table, [:client_message_id]))
  end

  def down do
    drop(table(@table))
  end
end
