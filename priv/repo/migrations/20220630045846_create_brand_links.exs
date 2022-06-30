defmodule Picsello.Repo.Migrations.CreateBrandLinks do
  use Ecto.Migration

  @table :brand_links

  def change do
    create table(@table) do
      add(:title, :string, null: false)
      add(:link_id, :string)
      add(:link, :string)
      add(:active?, :boolean, default: false)
      add(:use_publicly?, :boolean, default: false)
      add(:show_on_profile?, :boolean, default: false)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)
    end

    create(index(@table, [:organization_id]))
  end
end
