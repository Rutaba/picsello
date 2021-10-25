defmodule Picsello.Repo.Migrations.PackageTemplatesHaveJobTypes do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add(:job_type, references(:job_types, column: :name, type: :string))
    end

    execute(
      """
      update packages set job_type = (select name from job_types limit 1) where package_template_id is null
      """,
      ""
    )

    # package_template_id job_type
    # 1                     1    =  invalid -- cannot both *be* a template and *have* a template
    # 1                     0    =  valid -- package from template
    # 0                     1    =  valid -- package template
    # 0                     0    =  valid -- 1 off package without template
    create(
      constraint("packages", "templates_must_have_types",
        check:
          "((package_template_id is not null)::integer + (job_type is not null)::integer) < 2"
      )
    )
  end
end
