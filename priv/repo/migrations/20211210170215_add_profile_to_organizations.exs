defmodule Picsello.Repo.Migrations.AddProfileToOrganizations do
  use Ecto.Migration

  def up do
    alter table("organizations") do
      add(:profile, :map, default: fragment("'{}'::jsonb"))
    end

    execute("""
    update
      organizations
    set
      profile = (
        SELECT
          jsonb_object_agg(key, value)
        FROM
          jsonb_each(onboarding)
        WHERE
          key IN ('website', 'job_types', 'color')
      )
    from
      users
    where
      users.organization_id = organizations.id
    """)

    execute("""
    update
      users
    set
      onboarding = coalesce((
        SELECT
          jsonb_object_agg(key, value)
        FROM
          jsonb_each(onboarding)
        WHERE
          key not in ('website', 'job_types', 'color')
      ), '{}')
    """)
  end

  def down do
    execute("""
    update
      users
    set
      onboarding = users.onboarding || coalesce((
        SELECT
          jsonb_object_agg(key, value)
        FROM
          jsonb_each(profile)
        WHERE
          key IN ('website', 'job_types', 'color')
      ), '{}')
    from
      organizations
    where
      users.organization_id = organizations.id
    """)

    alter table("organizations") do
      remove(:profile)
    end
  end
end
