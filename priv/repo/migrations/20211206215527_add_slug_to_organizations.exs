defmodule Picsello.Repo.Migrations.AddSlugToOrganizations do
  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add(:slug, :string)
    end

    execute("""
      with slugs as (
        select id,
        trim(both '-' from regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g')) as slug
        from organizations
      ),
      numbered_slugs as (
        select
        id,
        slug,
        row_number() over(partition by slug order by id) as number
        from slugs
      )
      update organizations set slug=(select slug || case when number = 1 then '' else '-' || number end from numbered_slugs where numbered_slugs.id = organizations.id)
    """)

    create(unique_index(:organizations, :slug))

    alter table(:organizations) do
      modify(:slug, :string, null: false)
    end
  end

  def down do
    alter table(:organizations) do
      remove(:slug)
    end
  end
end
