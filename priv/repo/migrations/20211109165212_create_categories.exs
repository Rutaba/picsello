defmodule Picsello.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add(:deleted_at, :utc_datetime)
      add(:hidden, :boolean, default: true, null: false)
      add(:icon, :string, null: false)
      add(:name, :string, null: false)
      add(:position, :integer, null: false)
      add(:whcc_id, :string, null: false)
      add(:whcc_name, :string, null: false)

      add(:inserted_at, :utc_datetime,
        null: false,
        default: fragment("(now() at time zone 'utc')")
      )

      add(:updated_at, :utc_datetime, null: false, default: fragment("(now() at time zone 'utc')"))
    end

    create(unique_index(:categories, [:whcc_id]))
    create(unique_index(:categories, [:position], where: "deleted_at is null"))
  end
end
