defmodule Picsello.Repo.Migrations.CreatePaymentSchedules do
  use Ecto.Migration

  def change do
    create table(:payment_schedules) do
      add :price, :integer, null: false
      add :due_at, :utc_datetime, null: false
      add :paid_at, :utc_datetime
      add :job_id, references(:jobs, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:payment_schedules, [:job_id])

    execute(
      """
       insert into payment_schedules (job_id, price, due_at, paid_at, inserted_at, updated_at)
       select j.id, (p.base_price * p.base_multiplier) * 0.5, bp.inserted_at, bp.deposit_paid_at, bp.inserted_at, bp.updated_at
       from booking_proposals bp join jobs j on j.id = bp.job_id join packages p on p.id = j.package_id
      """,
      ""
    )

    execute(
      """
       insert into payment_schedules (job_id, price, due_at, paid_at, inserted_at, updated_at)
       select distinct on (j.id) j.id, (p.base_price * p.base_multiplier) * 0.5, s.starts_at - interval '1 day', bp.remainder_paid_at, bp.inserted_at, bp.updated_at
       from booking_proposals bp join jobs j on j.id = bp.job_id join packages p on p.id = j.package_id join shoots s on s.job_id = j.id
       order by j.id, s.starts_at
      """,
      ""
    )
  end
end
