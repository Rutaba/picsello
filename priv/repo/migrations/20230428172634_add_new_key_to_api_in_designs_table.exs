defmodule Picsello.Repo.Migrations.AddNewKeyToApiInDesignsTable do
  use Ecto.Migration

  def change do
    execute(
      """
      UPDATE designs
      SET api = jsonb_set(api, '{displayName}', to_jsonb(api->'family'->>'name'), true)
      """
    )
  end
end
