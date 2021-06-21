defmodule Picsello.Repo.Migrations.CreatePackages do
  use Ecto.Migration

  def change do
    create table(:packages) do
      add(:price, :integer, null: false)
      add(:name, :text, null: false)
      add(:description, :text, null: false)
      add(:shoot_count, :integer, null: false)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(:packages, [:organization_id]))

    alter table(:jobs) do
      add(:package_id, references(:packages, on_delete: :nothing))
    end

    create(index(:jobs, [:package_id]))
  end
end
