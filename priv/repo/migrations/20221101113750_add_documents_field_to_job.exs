defmodule Picsello.Repo.Migrations.AddDocumentsFieldToJob do
  use Ecto.Migration

  def up do
    alter table(:jobs) do
      add(:documents, :jsonb)
    end
  end

  def down do
    alter table(:jobs) do
      remove(:documents, :jsonb)
    end
  end
end
