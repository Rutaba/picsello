defmodule Picsello.Repo.Migrations.RemoveCCFromClientMessageCreateClientMessageRecipient do
  use Ecto.Migration

  alias Picsello.{Repo, ClientMessage}
  @table :client_message_recipients

  def up do
    execute("CREATE TYPE recipient_type AS ENUM ('to','cc','bcc','from')")

    create table(@table) do
      add(:client_id, references(:clients, on_delete: :nothing), null: false)
      add(:client_message_id, references(:client_messages, on_delete: :nothing), null: false)
      add(:recipient_type, :string, null: false, default: "to")

      timestamps(type: :utc_datetime)
    end

    create(index(@table, [:client_id, :client_message_id], unique: true))

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    client_messages = Repo.all(ClientMessage) |> Repo.preload([:job])

    Enum.map(client_messages, fn msg ->
      if Map.has_key?(msg, :client_id) || msg.job,
        do:
          execute("""
            INSERT INTO #{@table} ("client_id", "client_message_id", recipient_type, inserted_at, updated_at) VALUES (#{if Map.has_key?(msg, :client_id), do: msg.client_id, else: msg.job.client_id}, #{msg.id}, 'to', '#{now}', '#{now}');
          """)
    end)

    drop_if_exists(index(:client_messages, [:client_id]))

    alter table(:client_messages) do
      remove(:cc_email, :string)
      remove(:client_id, references(:clients))
    end
  end

  def down do
    execute("DROP TYPE recipient_type")

    alter table(:client_messages) do
      add(:cc_email, :string, null: true)
      add(:client_id, references(:clients))
    end

    drop(table(@table))
  end
end
