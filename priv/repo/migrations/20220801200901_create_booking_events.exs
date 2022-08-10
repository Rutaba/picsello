defmodule Picsello.Repo.Migrations.CreateBookingEvents do
  use Ecto.Migration

  def change do
    create table(:booking_events) do
      add(:name, :string, null: false)
      add(:location, :string, null: false)
      add(:address, :string, null: false)
      add(:duration_minutes, :integer, null: false)
      add(:buffer_minutes, :integer)
      add(:description, :string, null: false)
      add(:thumbnail_url, :string, null: false)
      add(:package_template_id, references(:packages, on_delete: :nothing), null: false)
      add(:dates, :map, null: false)

      timestamps()
    end

    create(index(:booking_events, [:package_template_id]))
  end
end
