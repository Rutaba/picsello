defmodule Picsello.Repo.Migrations.ArchivePackageTemplates do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add(:archived_at, :utc_datetime)
    end

    create(
      constraint(:packages, "only_archive_templates",
        check: "archived_at is null or (package_template_id is null and job_type is not null)"
      )
    )
  end
end
