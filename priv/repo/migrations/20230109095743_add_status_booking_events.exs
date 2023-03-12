defmodule Picsello.Repo.Migrations.AddStatusBookingEvents do
  use Ecto.Migration

  def up do
    execute("CREATE TYPE booking_events_status AS ENUM ('active','disabled','archive')")

    alter table(:booking_events) do
      add(:status, :booking_events_status, default: "active")
    end

    execute("UPDATE booking_events SET status='disabled' WHERE disabled_at IS NOT NULL;")

    execute("""
      ALTER TABLE "public"."booking_events"
      DROP COLUMN disabled_at;
    """)
  end

  def down do
    alter table(:booking_events) do
      add(:disabled_at, :utc_datetime)
    end

    current_time = DateTime.utc_now() |> DateTime.truncate(:second)

    execute(
      "UPDATE booking_events SET disabled_at='2023-02-20 17:12:15' WHERE status='disabled';"
    )

    execute("""
      ALTER TABLE "public"."booking_events"
      DROP COLUMN status
    """)

    execute("DROP TYPE booking_events_status")
  end
end
