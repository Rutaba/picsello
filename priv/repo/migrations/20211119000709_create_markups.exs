defmodule Picsello.Repo.Migrations.CreateMarkups do
  use Ecto.Migration

  def change do
    create table(:markups) do
      add(:organization_id, references("organizations"), null: false)
      add(:product_id, references("products"), null: false)
      add(:whcc_attribute_id, :text, null: false)
      add(:whcc_attribute_category_id, :text, null: false)
      add(:whcc_variation_id, :text, null: false)
      add(:value, :float, null: false)

      timestamps(type: :utc_datetime)
    end

    create(
      unique_index(
        :markups,
        ~w[organization_id product_id whcc_attribute_id whcc_variation_id whcc_attribute_category_id]
      )
    )
  end
end
