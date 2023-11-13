defmodule Picsello.Repo.Migrations.AddParentIdToCampanignTable do
  use Ecto.Migration

  def change do
    alter table(:campaigns) do
      add(:parent_id, references(:campaigns, column: :id))
    end
  end
end
