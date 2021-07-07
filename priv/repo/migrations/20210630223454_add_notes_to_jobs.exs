defmodule Picsello.Repo.Migrations.AddNotesToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add(:notes, :text)
    end
  end
end
