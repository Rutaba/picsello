defmodule Picsello.PaymentSchedules do
  @moduledoc "context module for payment schedules"

  alias Picsello.{Repo, Job, Package, PaymentSchedule}

  def build_payment_schedules_for_lead(%Job{} = job) do
    %{package: package, shoots: shoots} = job |> Repo.preload([:package, :shoots])

    price = package |> Package.price() |> Money.multiply(0.5)

    next_shoot_date =
      shoots
      |> Enum.sort_by(& &1.starts_at, DateTime)
      |> Enum.at(0)
      |> Map.get(:starts_at)
      |> DateTime.add(-1 * :timer.hours(24), :millisecond)
      |> DateTime.truncate(:second)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      %{
        price: price,
        job_id: job.id,
        due_at: now,
        inserted_at: now,
        updated_at: now,
        description: "50% retainer"
      },
      %{
        price: price,
        job_id: job.id,
        due_at: next_shoot_date,
        inserted_at: now,
        updated_at: now,
        description: "50% remainder"
      }
    ]
  end

  def has_payments?(%Job{} = job) do
    job |> payment_schedules() |> Enum.any?()
  end

  def all_paid?(%Job{} = job) do
    job |> payment_schedules() |> Enum.all?(&PaymentSchedule.paid?/1)
  end

  def total_price(%Job{} = job) do
    job
    |> payment_schedules()
    |> Enum.reduce(Money.new(0), fn payment, acc -> Money.add(acc, payment.price) end)
  end

  def paid_price(%Job{} = job) do
    job
    |> payment_schedules()
    |> Enum.filter(&(&1.paid_at != nil))
    |> Enum.reduce(Money.new(0), fn payment, acc -> Money.add(acc, payment.price) end)
  end

  def owed_price(%Job{} = job) do
    job
    |> payment_schedules()
    |> Enum.filter(&(&1.paid_at == nil))
    |> Enum.reduce(Money.new(0), fn payment, acc -> Money.add(acc, payment.price) end)
  end

  def remainder_due_on(%Job{} = job) do
    job |> remainder_payment() |> Map.get(:due_at)
  end

  def remainder_paid_at(%Job{} = job) do
    job |> remainder_payment() |> Map.get(:paid_at)
  end

  def unpaid_payment(job) do
    job |> payment_schedules() |> Enum.find(&(!paid?(&1)))
  end

  def past_due?(%PaymentSchedule{due_at: due_at}) do
    diff = DateTime.diff(due_at, DateTime.utc_now(), :millisecond) / 1000
    diff < 0
  end

  def payment_schedules(job) do
    Repo.preload(job, [:payment_schedules])
    |> Map.get(:payment_schedules)
    |> Enum.sort_by(& &1.due_at)
  end

  defp remainder_payment(job) do
    job |> payment_schedules() |> Enum.at(-1) || %PaymentSchedule{}
  end

  defdelegate paid?(payment_schedule), to: PaymentSchedule
end
