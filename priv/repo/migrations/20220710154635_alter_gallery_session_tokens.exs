defmodule Picsello.Repo.Migrations.AltergallerySessionTokens do
  use Ecto.Migration

  def up do
    alter table(:gallery_session_tokens) do
      add(:resource_type, :string)
    end

    rename(table(:gallery_session_tokens), to: table(:session_tokens))
    rename(table(:session_tokens), :gallery_id, to: :resource_id)

    drop(index(:gallery_session_tokens, [:gallery_id, :token]))
    create(unique_index(:session_tokens, [:resource_id, :resource_type, :token]))

    execute("ALTER TABLE session_tokens DROP CONSTRAINT gallery_session_tokens_gallery_id_fkey")

    execute(
      "ALTER TABLE session_tokens RENAME CONSTRAINT gallery_session_tokens_pkey TO session_tokens_pkey"
    )

    execute(
      "ALTER INDEX gallery_session_tokens_gallery_id_index RENAME TO session_tokens_resource_id_index"
    )

    execute("update session_tokens set resource_type = 'gallery'")
    execute("alter table session_tokens alter column resource_type set not null;")
  end

  def down do
    rename(table(:session_tokens), to: table(:gallery_session_tokens))
    rename(table(:gallery_session_tokens), :resource_id, to: :gallery_id)

    alter table(:gallery_session_tokens) do
      remove(:resource_type)
      modify(:gallery_id, references(:galleries, on_delete: :delete_all), null: false)
    end

    execute(
      "ALTER TABLE gallery_session_tokens RENAME CONSTRAINT session_tokens_pkey TO gallery_session_tokens_pkey"
    )

    execute(
      "ALTER INDEX session_tokens_resource_id_index RENAME TO gallery_session_tokens_gallery_id_index"
    )

    create(unique_index(:gallery_session_tokens, [:gallery_id, :token]))
  end
end
