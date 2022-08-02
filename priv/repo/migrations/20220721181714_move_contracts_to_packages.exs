defmodule Picsello.Repo.Migrations.MoveContractsToPackages do
  use Ecto.Migration

  def up do
    execute(
      "delete from contracts where id in (select c.id from contracts c join jobs j on j.id = c.job_id where j.package_id is null);"
    )

    execute("alter table contracts drop constraint contracts_job_id_fkey")

    drop(unique_index(:contracts, [:job_id]))

    rename(table(:contracts), :job_id, to: :package_id)

    execute("""
      update contracts set package_id = jobs.package_id from jobs where contracts.package_id = jobs.id;
    """)

    alter table(:contracts) do
      modify(:package_id, references(:packages, on_delete: :nothing))
    end

    create(unique_index(:contracts, [:package_id]))

    execute(
      "alter table contracts rename constraint job_contracts_must_have_template to package_contracts_must_have_template;"
    )

    execute(
      "alter table contracts rename constraint templates_cannot_have_org_id_and_job_id to templates_cannot_have_org_id_and_package_id;"
    )
  end

  def down do
    execute("alter table contracts drop constraint contracts_package_id_fkey")

    drop(unique_index(:contracts, [:package_id]))

    rename(table(:contracts), :package_id, to: :job_id)

    execute("""
      update contracts set job_id = jobs.id from jobs where contracts.job_id = jobs.package_id;
    """)

    alter table(:contracts) do
      modify(:job_id, references(:jobs, on_delete: :nothing))
    end

    create(unique_index(:contracts, [:job_id]))

    execute(
      "alter table contracts rename constraint package_contracts_must_have_template to job_contracts_must_have_template;"
    )

    execute(
      "alter table contracts rename constraint templates_cannot_have_org_id_and_package_id to templates_cannot_have_org_id_and_job_id;"
    )
  end
end
