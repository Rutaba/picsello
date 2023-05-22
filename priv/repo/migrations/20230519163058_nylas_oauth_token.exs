defmodule Picsello.Repo.Migrations.NylasOauthToken do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:nylas_oauth_token, :string, null: true)
    end
  end

  def down do
    alter table(:users) do
      remove_if_exists(:nylas_oauth_token, :string)
    end
  end
end
