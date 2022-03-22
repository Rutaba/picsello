defmodule Picsello.Repo.Migrations.AddDescriptionToPaymentSchedules do
  use Ecto.Migration

  def change do
    alter table(:payment_schedules) do
      add(:description, :text)
    end

    execute(
      """
        with retainers as (
          select distinct on (s.job_id) s.job_id, id
          from payment_schedules s
          order by s.job_id, s.due_at
        )
        update payment_schedules set description = '50% retainer' from retainers where retainers.id = payment_schedules.id
      """,
      ""
    )

    execute(
      """
        with remainders as (
          select distinct on (s.job_id) s.job_id, id
          from payment_schedules s
          order by s.job_id, s.due_at desc
        )
        update payment_schedules set description = '50% remainder' from remainders where remainders.id = payment_schedules.id
      """,
      ""
    )

    alter table(:payment_schedules) do
      modify(:description, :text, null: false)
    end
  end
end
