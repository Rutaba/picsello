defmodule Picsello.Repo.Migrations.AddTypeToEmailPresets do
  use Ecto.Migration

  def up do
    alter table(:email_presets) do
      add(:type, :string)
    end

    execute("update email_presets set type = 'job';")

    alter table(:email_presets) do
      modify(:type, :string, null: false)
      modify(:job_type, :string, null: true)
    end

    create(
      constraint(:email_presets, "job_must_have_job_type",
        check: "((type = 'job')::integer + (job_type is not null)::integer) % 2 = 0"
      )
    )

    rename(table(:email_presets), :job_state, to: :state)
  end

  def down do
    drop(constraint(:email_presets, "job_must_have_job_type"))

    alter table(:email_presets) do
      remove(:type, :string)
      modify(:job_type, :string, null: false)
    end

    rename(table(:email_presets), :state, to: :job_state)
  end
end
