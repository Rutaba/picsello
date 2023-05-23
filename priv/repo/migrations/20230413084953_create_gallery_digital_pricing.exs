defmodule Picsello.Repo.Migrations.CreateGalleryDigitalPricing do
  use Ecto.Migration

  @table :gallery_digital_pricing
  def up do
    create table(@table) do
      add(:download_count, :integer, null: false)
      add(:print_credits, :integer)
      add(:buy_all, :integer)
      add(:download_each_price, :integer)
      add(:email_list, {:array, :string})
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end
  end

  def down do
    drop(table(@table))
  end
end
