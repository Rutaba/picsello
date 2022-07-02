defmodule Picsello.Repo.Migrations.CreateBrandLinks do
  use Ecto.Migration

  @table :brand_links

  def change do
    create table(@table) do
      add(:title, :string, null: false)
      add(:link_id, :string, null: false)
      add(:link, :string)
      add(:active?, :boolean, null: false, default: false)
      add(:use_publicly?, :boolean, null: false, default: false)
      add(:show_on_profile?, :boolean, null: false, default: false)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)
    end

    create(index(@table, [:organization_id]))
  end
end
