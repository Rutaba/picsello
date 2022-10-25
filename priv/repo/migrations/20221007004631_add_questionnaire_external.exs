defmodule Picsello.Repo.Migrations.AddQuestionnaireExternal do
  use Ecto.Migration

  def change do
    alter table(:questionnaires) do
      add(:organization_id, references(:organizations, on_delete: :nothing))
      add(:is_organization_default, :boolean, default: false)
      add(:is_picsello_default, :boolean, default: false)
      add(:name, :string, null: false, default: "")
    end

    execute("""
      update questionnaires set is_picsello_default = true where organization_id is null and name = '';
    """)
  end

  def down do
    alter table(:questionnaires) do
      remove(:organization_id)
      remove(:is_organization_default)
      remove(:is_picsello_default)
      remove(:name)
    end
  end
end
