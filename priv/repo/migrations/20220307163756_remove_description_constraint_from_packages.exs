defmodule Picsello.Repo.Migrations.RemoveDescriptionConstraintFromPackages do
  use Ecto.Migration

  def up do
    alter table(:packages) do
      modify(:description, :text, null: true)
    end
  end

  def down do
    execute("update packages set description = 'Description' where description is null;")

    alter table(:packages) do
      modify(:description, :text, null: false)
    end
  end
end
