defmodule Picsello.Repo.Migrations.UpdateInsFunction do
  use Ecto.Migration

  def up do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    execute("""
      CREATE OR REPLACE FUNCTION ins_function() RETURNS TRIGGER AS $$
      --
      -- Perform AFTER INSERT operation on organizations by creating rows with new.id.
      --
      BEGIN
        INSERT INTO organization_job_types("show_on_profile?", "show_on_business?", job_type, organization_id, inserted_at, updated_at)
        SELECT false as "show_on_profile?", (CASE WHEN name = 'global' THEN true ELSE false END) as "show_on_business?", name, NEW.id, '#{now}' as inserted_at, '#{now}' as updated_at
        FROM job_types;

        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    """)

    execute("""
      -- Check if the trigger already exists before creating it
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'insert_organization_job_types' AND tgrelid = 'organizations'::regclass) THEN
          CREATE TRIGGER insert_organization_job_types AFTER INSERT
            ON organizations FOR EACH ROW EXECUTE PROCEDURE ins_function();
        END IF;
      END $$;
    """)
  end

  def down do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    execute("""
      CREATE OR REPLACE FUNCTION ins_function() RETURNS TRIGGER AS $$
      --
      -- Perform AFTER INSERT operation on organizations by creating rows with new.id.
      --
      BEGIN
        INSERT INTO organization_job_types("show_on_profile?", "show_on_business?", job_type, organization_id, inserted_at, updated_at)
        SELECT false as "show_on_profile?", (CASE WHEN name = 'other' THEN true ELSE false END) as "show_on_business?", name, NEW.id, '#{now}' as inserted_at, '#{now}' as updated_at
        FROM job_types;

        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    """)

    execute("""
    DROP TRIGGER IF EXISTS insert_organization_job_types ON organizations;
    """)
  end
end
