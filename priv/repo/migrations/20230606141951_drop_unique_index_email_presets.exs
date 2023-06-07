defmodule Picsello.Repo.Migrations.DropUniqueIndexEmailPresets do
  use Ecto.Migration

  def up do
    drop(constraint(:email_presets, "job_must_have_job_type"))
  end

  def down do
    create(
      constraint(:email_presets, "job_must_have_job_type",
        check: "((type = 'job')::integer + (job_type is not null)::integer) % 2 = 0"
      )
    )
  end
end
