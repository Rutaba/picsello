defmodule Picsello.Repo.Migrations.MoveStripeAccountIdToOrganizations do
  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add(:stripe_account_id, :text)
    end

    execute("""
      update organizations set stripe_account_id = users.stripe_account_id from users where users.organization_id = organizations.id;
    """)

    alter table(:users) do
      remove(:stripe_account_id)
    end
  end

  def down do
    alter table(:users) do
      add(:stripe_account_id, :text)
    end

    execute("""
      update users set stripe_account_id = organizations.stripe_account_id from organizations where users.organization_id = organizations.id;
    """)

    alter table(:organizations) do
      remove(:stripe_account_id)
    end
  end
end
