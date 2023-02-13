defmodule Picsello.Repo.Migrations.AddStatusBookingEvents do
  use Ecto.Migration

  def up do
    execute("""
      ALTER TABLE "public"."booking_events"
      ADD COLUMN status VARCHAR
      DEFAULT 'active';
    """)

    execute("UPDATE booking_events SET status='disable' WHERE disabled_at IS NOT NULL;")

    alter table(:booking_events) do
      remove(:disabled_at)
    end
  end

  def down do
    alter table(:booking_events) do
      add(:disabled_at, :utc_datetime)
      remove(:status)
    end

    current_time = DateTime.utc_now() |> DateTime.truncate(:second)
    execute("UPDATE booking_events SET disabled_at= #{current_time} WHERE status='disabled';")
  end
end
