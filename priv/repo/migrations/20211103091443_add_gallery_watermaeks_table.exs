defmodule Picsello.Repo.Migrations.AddGalleryWatermaeksTable do
  use Ecto.Migration

  @type_name "watermark_type"
  def change do
    execute(
      "CREATE TYPE #{@type_name} AS ENUM ('image','text')",
      "DROP TYPE #{@type_name}"
    )

    create table(:gallery_watermarks) do
      add(:name, :string)
      add(:type, :"#{@type_name}", null: false)
      add(:size, :integer)
      add(:text, :string)
      add(:gallery_id, references(:galleries, on_delete: :delete_all), null: false)

      timestamps()
    end

    create index(:gallery_watermarks, [:gallery_id])
  end
end
