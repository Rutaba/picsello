defmodule Picsello.Repo.Migrations.CreateGalleries do
  use Ecto.Migration

  def change do
    create table(:galleries) do
      add :name, :string
      add :status, :string
      add :cover_photo_id, :integer
      add :expired_at, :utc_datetime
      add :password, :string
      add :client_link_hash, :string
      add :job_id, references(:jobs, on_delete: :nothing)

      timestamps()
    end

    create index(:galleries, [:job_id])
  end
end
