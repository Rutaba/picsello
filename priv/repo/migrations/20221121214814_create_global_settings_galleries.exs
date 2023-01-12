defmodule Picsello.Repo.Migrations.CreateGlobalSettingsGalleries do
  use Ecto.Migration

  @type_name "global_watermark_type"

  def change do
    execute(
      "CREATE TYPE #{@type_name} AS ENUM ('image','text')",
      "DROP TYPE #{@type_name}"
    )

    create table(:global_settings_galleries) do
      add(:expiration_days, :integer)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)
      add(:watermark_name, :string)
      add(:watermark_type, :"#{@type_name}")
      add(:watermark_size, :integer)
      add(:watermark_text, :string)
      add(:global_watermark_path, :string)
      timestamps()
    end

    create(index(:global_settings_galleries, [:organization_id]))
  end
end
