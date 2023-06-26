defmodule Picsello.Repo.Migrations.DropUniqueIndexEmailPresets do
  use Ecto.Migration

  @table :email_presets
  def up do
    alter table(@table) do
      remove(:state, :string)
    end
    drop(constraint(@table, "job_must_have_job_type"))
  end

  def down do
    create(
      constraint(@table, "job_must_have_job_type",
        check: "((type = 'job')::integer + (job_type is not null)::integer) % 2 = 0"
      )
    )
  end
end
