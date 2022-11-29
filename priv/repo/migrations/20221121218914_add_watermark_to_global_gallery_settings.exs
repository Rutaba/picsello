defmodule Picsello.Repo.Migrations.AddWatermarkToGlobalGallerySettings do
  use Ecto.Migration
  @type_name "global_watermark_type"

  def change do
    execute(
      "CREATE TYPE #{@type_name} AS ENUM ('image','text')",
      "DROP TYPE #{@type_name}"
    )
    alter table(:global_gallery_settings) do
      add(:watermark_name, :string)
      add(:watermark_type, :"#{@type_name}")
      add(:watermark_size, :integer)
      add(:watermark_text, :string)
    end
  end
end
