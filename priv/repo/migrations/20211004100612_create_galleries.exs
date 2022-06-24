defmodule Picsello.Repo.Migrations.CreateGalleries do
  use Ecto.Migration

  @type_name "gallery_status"

  def change do
    execute(
      """
      CREATE TYPE #{@type_name}
        AS ENUM ('draft','active','expired')
      """,
      "DROP TYPE #{@type_name}"
    )

    create table(:galleries) do
      add(:name, :string, null: false)
      add(:status, :"#{@type_name}", null: false)
      add(:cover_photo_id, :integer)
      add(:expired_at, :utc_datetime)
      add(:password, :string)
      add(:client_link_hash, :string)
      add(:job_id, references(:jobs, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(:galleries, [:job_id]))
  end
end
