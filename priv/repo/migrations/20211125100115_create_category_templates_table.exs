defmodule Picsello.Repo.Migrations.CategoryTemplates do
  use Ecto.Migration

  def change do
    create table(:category_templates) do
      add(:frame_url, :string)
      add(:price, :integer, default: 0)
      add(:category_id, references(:categories, on_delete: :nothing))

      timestamps()
    end
  end
end
