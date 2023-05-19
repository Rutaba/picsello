defmodule Picsello.Repo.Migrations.NylasOauthToken do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:nylas_oauth_token, :string, null: true)
    end
  end
end
