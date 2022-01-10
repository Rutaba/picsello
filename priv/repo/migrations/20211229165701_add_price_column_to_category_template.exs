defmodule Picsello.Repo.Migrations.AddPriceColumnToCategoryTemplate do
  use Ecto.Migration

  def change do
    alter table("category_templates") do
      add :price, :integer, null: false
    end
  end
end
