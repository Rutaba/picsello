defmodule Picsello.Repo.Migrations.AddIsProofingToAlbum do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add(:is_proofing, :boolean, null: false, default: false)
    end

    execute("update albums set is_proofing = false", "")
  end
end
