defmodule Picsello.Repo.Migrations.AddSignUpAuthProviderToUser do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:sign_up_auth_provider, :string)
    end

    execute("""
      update users set sign_up_auth_provider='password'
    """)

    alter table(:users) do
      modify(:sign_up_auth_provider, :string, null: false)
    end
  end

  def down do
    alter table(:users) do
      remove(:sign_up_auth_provider)
    end
  end
end
