defmodule Picsello.Repo.Migrations.CreateShoots do
  use Ecto.Migration

  def change do
    create table(:shoots) do
      add :starts_at, :utc_datetime
      add :duration_minutes, :integer
      add :name, :text
      add :location, :text
      add :notes, :text
      add :job_id, references(:jobs, on_delete: :nothing)

      timestamps()
    end

    create index(:shoots, [:job_id])
  end
end
