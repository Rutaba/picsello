defmodule Picsello.Repo.Migrations.AddOrderIdToEmailSchedules do
  use Ecto.Migration

  def up do
    alter table(:email_schedules) do
      add(:order_id, references(:gallery_orders, on_delete: :nothing))
    end
  end

  def down do
    alter table(:email_schedules) do
      remove(:order_id)
    end
  end
end
