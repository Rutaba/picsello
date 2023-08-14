defmodule Picsello.Repo.Migrations.AlterTablePackagesAddIsTemplate do
  use Ecto.Migration

  @table :packages
  def up do
    alter table(@table) do
      add(:is_template, :boolean, null: false, default: false)
    end

    create(index(@table, [:is_template]))

    drop(constraint(@table, "templates_must_have_types"))

    create(
      constraint(@table, "templates_must_have_is_template_true",
        check: "((package_template_id is not null)::integer + (is_template is true)::integer) < 2"
      )
    )

    flush()

    execute("""
      update packages set is_template = true where job_type is not null and package_template_id is null
    """)

    execute("""
      update packages set is_template = false where package_template_id is not null and is_template is true
    """)
  end

  def down do
    alter table(@table) do
      remove(:is_template, :boolean)
    end

    drop(constraint(@table, "templates_must_have_is_template_true"))

    create(
      constraint(@table, "templates_must_have_types",
        check:
          "((package_template_id is not null)::integer + (job_type is not null)::integer) < 2"
      )
    )
  end
end
