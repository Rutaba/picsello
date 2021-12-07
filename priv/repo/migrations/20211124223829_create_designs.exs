defmodule Picsello.Repo.Migrations.CreateDesigns do
  use Ecto.Migration

  def change do
    create table(:designs) do
      add(:api, :map, null: false, default: fragment("'{}'::jsonb"))
      add(:attribute_categories, :map, null: false, default: fragment("'[]'::jsonb"))
      add(:deleted_at, :utc_datetime)
      add(:position, :integer, null: false)
      add(:product_id, references(:products), null: false)
      add(:whcc_id, :string, null: false)
      add(:whcc_name, :string, null: false)

      add(:inserted_at, :utc_datetime,
        null: false,
        default: fragment("(now() at time zone 'utc')")
      )

      add(:updated_at, :utc_datetime, null: false, default: fragment("(now() at time zone 'utc')"))
    end

    create(unique_index(:designs, [:whcc_id]))
    create(index(:designs, [:position], where: "deleted_at is null"))
    drop(unique_index(:products, [:position], where: "deleted_at is null"))
    create(index(:products, [:position], where: "deleted_at is null"))
  end
end
