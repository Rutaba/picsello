defmodule Picsello.Repo.Migrations.RemoveCCFromClientMessageCreateClientMessageRecipient do
  use Ecto.Migration

  alias Picsello.{Repo, ClientMessage}
  @table :client_message_recipients

  def up do
    create table(@table) do
      add(:client_id, references(:clients))
      add(:client_message_id, references(:client_messages))
      add(:recipient_type, :string)

      timestamps()
    end

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    client_messages = Repo.all(ClientMessage) |> Repo.preload([:client, :job])

    Enum.map(client_messages, fn msg ->
      execute("""
        INSERT INTO #{@table} ("client_id", "client_message_id", recipient_type, inserted_at, updated_at) VALUES (#{if msg.client, do: msg.client.id, else: msg.job.client_id}, #{msg.id}, 'to', '#{now}', '#{now}');
      """)
    end)

    drop(index(:client_messages, [:client_id]))

    alter table(:client_messages) do
      remove(:cc_email, :string)
      remove(:client_id, references(:clients))
    end
  end

  def down do
    alter table(:client_messages) do
      add(:cc_email, :string, null: true)
      add(:client_id, references(:clients))
      remove(:recipient_type, :string)
    end

    drop table(@table)
  end
end
