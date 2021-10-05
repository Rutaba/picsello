defmodule Picsello.Repo.Migrations.CreateGalleries do
  use Ecto.Migration

  def change do
    create table(:galleries) do
      add(:name, :string, null: false)
      add(:status, :string, null: false)
      add(:cover_photo_id, :integer)
      add(:expired_at, :utc_datetime)
      add(:password, :string)
      add(:client_link_hash, :string)
      add(:job_id, references(:jobs, on_delete: :nothing), null: false)

      timestamps()
    end

    create index(:galleries, [:job_id])
  end
end
