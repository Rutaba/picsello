defmodule Picsello.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string
      add :corners, {:array, {:array, :integer}}
      add :template_image_url, :string
      
      timestamps()
    end

  end
end
