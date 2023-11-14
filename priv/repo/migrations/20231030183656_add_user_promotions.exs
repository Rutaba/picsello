defmodule Picsello.Repo.Migrations.AddUserPromotions do
  use Ecto.Migration

  def change do
    create table(:user_promotions) do
      add(:state, :string)
      add(:slug, :string)
      add(:name, :string)

      add(:user_id, references(:users, on_delete: :nothing), null: false)

      timestamps()
    end
  end
end
