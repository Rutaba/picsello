defmodule Picsello.Repo.Migrations.AddPackageTemplateIdToPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add(:package_template_id, references(:packages, on_delete: :nothing))
    end

    create(index(:packages, [:package_template_id]))
  end
end
