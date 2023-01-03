defmodule Picsello.Repo.Migrations.QuestionnairesUniqueName do
  use Ecto.Migration

  def up do
    create_if_not_exists(
      unique_index(:questionnaires, [:name, :organization_id], where: "package_id is null")
    )
  end

  def down do
    drop_if_exists(
      unique_index(:questionnaires, [:name, :organization_id], where: "package_id is null")
    )
  end
end
