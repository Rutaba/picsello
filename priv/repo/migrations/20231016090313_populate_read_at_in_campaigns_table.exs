defmodule Picsello.Repo.Migrations.PopulateReadAtInCampaignsTable do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE campaigns SET read_at = now() where parent_id is NULL
    """)
  end
end
