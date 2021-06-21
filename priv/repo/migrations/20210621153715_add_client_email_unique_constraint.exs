defmodule Picsello.Repo.Migrations.AddClientEmailUniqueConstraint do
  use Ecto.Migration

  def change do
    create(unique_index(:clients, [:email, :organization_id]))
  end
end
