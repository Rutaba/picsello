defmodule Picsello.Repo.Migrations.AddTypeToEmailPresets do
  use Ecto.Migration

  def up do
    alter table(:email_presets) do
      add(:type, :string)
    end

    execute "update email_presets set type = 'job';"

    alter table(:email_presets) do
      modify(:type, :string, null: false)
      modify(:job_type, :string, null: true)
      modify(:job_state, :string, null: true)
    end

    create(
      constraint(:email_presets, "job_must_have_job_type",
        check: "((type = 'job')::integer + (job_type is not null)::integer) % 2 = 0"
      )
    )

    create(
      constraint(:email_presets, "job_must_have_job_state",
        check: "((type = 'job')::integer + (job_state is not null)::integer) % 2 = 0"
      )
    )
  end

  def down do
    drop constraint(:email_presets, "job_must_have_job_state")
    drop constraint(:email_presets, "job_must_have_job_type")

    alter table(:email_presets) do
      remove(:type, :string)
      modify(:job_type, :string, null: false)
      modify(:job_state, :text, null: false)
    end
  end
end
