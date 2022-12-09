defmodule Picsello.Repo.Migrations.CreateGlobalSettingsPrintProducts do
  use Ecto.Migration

  def change do
    create table(:global_settings_print_products) do
      add(:sizes, :jsonb)

      add(
        :global_settings_gallery_product_id,
        references(:global_settings_gallery_products, on_delete: :nothing),
        null: false
      )

      add(:product_id, references(:products, on_delete: :nothing), null: false)

      timestamps()
    end

    create(
      unique_index(:global_settings_print_products, [
        :product_id,
        :global_settings_gallery_product_id
      ])
    )
  end
end
