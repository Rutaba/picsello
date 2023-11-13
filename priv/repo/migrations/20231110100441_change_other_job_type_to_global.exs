defmodule Picsello.Repo.Migrations.ChangeOtherJobTypeToGlobal do
  use Ecto.Migration

  def up do
    # Step 1: Insert 'global' as a new row
    execute("""
    insert into job_types (name, position) values ('global', 9)
    """)

    # Step 2: Update foreign keys in associated tables
    execute("""
    update jobs
    set type = 'global'
    where type = 'other'
    """)

    execute("""
    update questionnaires
    set job_type = 'global'
    where job_type = 'other'
    """)

    execute("""
    update questionnaires
    set name = 'Picsello Global Template'
    where name = 'Picsello Other Template'
    """)

    execute("""
    update packages
    set job_type = 'global'
    where job_type = 'other'
    """)

    execute("""
    update organization_job_types
    set job_type = 'global'
    where job_type = 'other'
    """)

    execute("""
    update email_presets
    set job_type = 'global'
    where job_type = 'other'
    """)

    execute("""
    update package_base_prices
    set job_type = 'global'
    where job_type = 'other'
    """)

    execute("""
    update contracts
    set job_type = 'global'
    where job_type = 'other'
    """)

    execute("""
    UPDATE packages
    SET name =
      CASE
        WHEN name ILIKE '% Other' THEN CONCAT(SUBSTRING(name FROM 1 FOR POSITION(' Other' IN name) - 1), ' Global')
        ELSE name
      END;
    """)

    execute("""
    UPDATE packages
    SET description =
      CASE
        WHEN description ILIKE '% Other' THEN CONCAT(SUBSTRING(description FROM 1 FOR POSITION(' Other' IN description) - 1), ' Global')
        ELSE description
      END;
    """)

    # Step 3: Delete the old 'other' row
    execute("""
    delete from job_types where name = 'other'
    """)
  end

  def down do
    # Step 1: Re-insert 'other' as a new row
    execute("""
    insert into job_types (name, position) values ('other', 9)
    """)

    # Step 2: Update foreign keys in associated tables back to 'other'
    execute("""
    update jobs
    set type = 'other'
    where type = 'global'
    """)

    execute("""
    update contracts
    set job_type = 'other'
    where job_type = 'global'
    """)

    execute("""
    update questionnaires
    set job_type = 'other'
    where job_type = 'global'
    """)

    execute("""
    update questionnaires
    set name = 'Picsello Other Template'
    where name = 'Picsello Global Template'
    """)

    execute("""
    update packages
    set job_type = 'other'
    where job_type = 'global'
    """)

    execute("""
    update organization_job_types
    set job_type = 'other'
    where job_type = 'global'
    """)

    execute("""
    update email_presets
    set job_type = 'other'
    where job_type = 'global'
    """)

    execute("""
    update package_base_prices
    set job_type = 'other'
    where job_type = 'global'
    """)

    execute("""
    UPDATE packages
    SET name =
      CASE
        WHEN name ILIKE '% Global' THEN CONCAT(SUBSTRING(name FROM 1 FOR POSITION(' Global' IN name) - 1), ' Other')
        ELSE name
      END;
    """)

    execute("""
    UPDATE packages
    SET description =
      CASE
        WHEN description ILIKE '% Global' THEN CONCAT(SUBSTRING(description FROM 1 FOR POSITION(' Global' IN description) - 1), ' Other')
        ELSE description
      END;
    """)

    # Step 3: Delete the 'global' row
    execute("""
    delete from job_types where name = 'global'
    """)
  end
end
