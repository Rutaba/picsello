defmodule Picsello.Repo.Migrations.CreateOrganizationJobTypes do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]
  alias Picsello.{Repo, JobType}

  @table :organization_job_types
  def up do
    create table(@table) do
      add(:show_on_profile?, :boolean, null: false, default: false)
      add(:show_on_business?, :boolean, null: false, default: false)
      add(:job_type, references(:job_types, column: :name, type: :string, on_delete: :nothing))
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)

      timestamps()
    end

    create(unique_index(@table, [:job_type, :organization_id]))

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    organizations = from("organizations", select: [:id, :profile]) |> Picsello.Repo.all()
    job_types = Repo.all(JobType)

    Enum.map(organizations, fn org ->
      # insert organizations' job_types into organization_job_types and set show_on_profile and show_on_business accordingly.
      existing_job_types = if org.profile["job_types"], do: org.profile["job_types"], else: []

      Enum.map(job_types, fn type ->
        selected? = if type.name in existing_job_types, do: true, else: false

        execute("""
          INSERT INTO organization_job_types ("show_on_profile?", "show_on_business?", organization_id, job_type, inserted_at, updated_at) VALUES (#{selected?}, #{if type.name == "other", do: true, else: selected?}, #{org.id}, '#{type.name}', '#{now}', '#{now}');
        """)
      end)
    end)
  end

  def down do
    drop(unique_index(@table, [:job_type, :organization_id]))

    drop(table(@table))
  end
end
