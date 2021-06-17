defmodule Picsello.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def up do
    create table(:organizations) do
      add(:name, :string, null: false)
      # temporary column
      add(:user_id, :bigint)
      timestamps()
    end

    alter table(:users) do
      add(:organization_id, references(:organizations, on_delete: :nothing))
    end

    create(index(:users, [:organization_id]))

    execute("""
      insert into organizations (name, user_id, inserted_at, updated_at) select business_name, id, now(), now() from users;
    """)

    execute("""
      update users set organization_id = organizations.id from organizations where user_id = users.id;
    """)

    alter table(:users) do
      modify(:organization_id, :bigint, null: false)
    end

    alter table(:organizations) do
      remove(:user_id)
    end

    alter table(:users) do
      remove(:business_name)
    end
  end

  def down do
    alter table(:users) do
      add(:business_name, :string, null: false, default: "org")
      remove(:organization_id)
    end

    drop(table(:organizations))
  end
end
