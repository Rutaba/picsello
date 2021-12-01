defmodule Picsello.Repo.Migrations.AddGallerySessionTokens do
  use Ecto.Migration

  def change do
    create table(:gallery_session_tokens) do
      add :gallery_id, references(:galleries, on_delete: :delete_all), null: false
      add :token, :binary, null: false

      timestamps(updated_at: false)
    end

    create index(:gallery_session_tokens, [:gallery_id])
  end
end
