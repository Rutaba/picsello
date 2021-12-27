defmodule Picsello.Repo.Migrations.RemoveNameConstraintFromClients do
  use Ecto.Migration

  def up do
    alter table(:clients) do
      modify(:name, :string, null: true)
    end
  end

  def down do
    execute("update clients set name = 'Client' where name is null;")

    alter table(:clients) do
      modify(:name, :string, null: false)
    end
  end
end
