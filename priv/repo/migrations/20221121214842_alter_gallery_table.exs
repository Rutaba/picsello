defmodule Picsello.Repo.Migrations.AlterGalleryTable do
  use Ecto.Migration

  @new_type "gallery_statuses"
  @old_type "gallery_status"

  def up do
    execute("UPDATE galleries SET status='active' WHERE status='draft'")
    execute("CREATE TYPE #{@new_type} AS ENUM ('active','inactive','disabled', 'expired')")

    execute("""
    ALTER TABLE galleries
    ALTER COLUMN status
    SET DATA TYPE #{@new_type}
    USING status::text::#{@new_type};
    """)

    execute("UPDATE galleries SET status='disabled' WHERE disabled=true")
    execute("UPDATE galleries SET status='inactive' WHERE active=false")

    alter table(:galleries) do
      remove(:active)
      remove(:disabled)
    end

    execute("DROP TYPE #{@old_type}")
  end

  def down do
    execute("CREATE TYPE #{@old_type} AS ENUM ('active','expired','draft')")

    alter table(:galleries) do
      add(:active, :boolean, default: true)
      add(:disabled, :boolean, default: false)
    end

    execute("UPDATE galleries SET active=false WHERE status='inactive'")
    execute("UPDATE galleries SET disabled=true WHERE status='disabled'")
    execute("UPDATE galleries SET status='active' WHERE status='disabled' OR status='inactive'")

    execute("""
    ALTER TABLE galleries
    ALTER COLUMN status
    SET DATA TYPE #{@old_type}
    USING status::text::#{@old_type};
    """)

    execute("UPDATE galleries SET status='draft' WHERE status='active'")

    execute("DROP TYPE #{@new_type}")
  end
end
