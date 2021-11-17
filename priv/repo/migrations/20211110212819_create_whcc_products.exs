defmodule Picsello.Repo.Migrations.CreateWHCCProducts do
  use Ecto.Migration

  def change do
    rename(table(:products), to: table(:gallery_products))

    create table(:products) do
      add(:category_id, references(:categories), null: false)
      add(:deleted_at, :utc_datetime)
      add(:position, :integer, null: false)
      add(:whcc_id, :string, null: false)
      add(:whcc_name, :string, null: false)
      add(:attribute_categories, :map, null: false, default: fragment("'[]'::jsonb"))

      add(:inserted_at, :utc_datetime,
        null: false,
        default: fragment("(now() at time zone 'utc')")
      )

      add(:updated_at, :utc_datetime, null: false, default: fragment("(now() at time zone 'utc')"))
    end

    create(unique_index(:products, [:whcc_id]))
    create(unique_index(:products, [:position], where: "deleted_at is null"))
  end
end
