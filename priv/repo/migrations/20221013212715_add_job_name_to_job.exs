defmodule Picsello.Repo.Migrations.AddJobNameToJob do
  use Ecto.Migration

  def up do
    alter table(:jobs) do
      add_if_not_exists(:job_name, :string)
    end
  end

  def down do
    alter table(:jobs) do
      remove(:job_name, :string)
    end
  end
end
