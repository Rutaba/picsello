defmodule Picsello.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add(:name, :string, null: false)
      add(:corners, {:array, {:array, :integer}}, null: false)
      add(:template_image_url, :string, null: false)
      
      timestamps()
    end

  end
end
