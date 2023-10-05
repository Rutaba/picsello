defmodule Picsello.Repo.Migrations.AddCurrencyToGalleryOrdersTable do
  use Ecto.Migration

  def up do
    alter table(:gallery_orders) do
      add(:currency, references(:currencies, type: :string, column: :code), default: "USD")
    end
  end

  def down do
    alter table(:gallery_orders) do
      remove(:currency, references(:currencies, type: :string, column: :code), default: "USD")
    end
  end
end
