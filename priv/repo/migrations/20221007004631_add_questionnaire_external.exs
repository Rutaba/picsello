defmodule Picsello.Repo.Migrations.AddQuestionnaireExternal do
  use Ecto.Migration

  def change do
    alter table(:questionnaires) do
      add(:organization_id, references(:organizations, on_delete: :nothing))
      add(:is_organization_default, :boolean, default: false)
      add(:is_picsello_default, :boolean, default: false)
      add(:name, :string, null: false, default: "")
    end
  end
end
