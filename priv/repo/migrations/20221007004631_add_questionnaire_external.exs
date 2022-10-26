defmodule Picsello.Repo.Migrations.AddQuestionnaireExternal do
  use Ecto.Migration

  def change do
    alter table(:questionnaires) do
      add(:organization_id, references(:organizations, on_delete: :nothing))
      add(:package_id, references(:packages, on_delete: :nothing))
      add(:is_organization_default, :boolean, default: false)
      add(:is_picsello_default, :boolean, default: false)
      add(:name, :string, null: false, default: "")
    end

    alter table(:packages) do
      add(:questionnaire_template_id, references(:questionnaires, on_delete: :nothing))
    end

    execute("""
      update questionnaires set is_picsello_default = true where organization_id is null and name = '';
    """)
  end

  def down do
    alter table(:questionnaires) do
      remove(:organization_id, references(:organizations, on_delete: :nothing))
      remove(:package_id, references(:packages, on_delete: :nothing))
      remove(:is_organization_default)
      remove(:is_picsello_default)
      remove(:name)
    end

    alter table(:packages) do
      remove(:questionnaire_template_id, references(:questionnaires, on_delete: :nothing))
    end
  end
end
