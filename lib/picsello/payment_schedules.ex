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
      %{price: price, job_id: job.id, due_at: now, inserted_at: now, updated_at: now},
      %{
        price: price,
        job_id: job.id,
        due_at: next_shoot_date,
        inserted_at: now,
        updated_at: now
      }
    ]
  end

  def deposit_price(%Job{} = job) do
    job |> deposit_payment() |> Map.get(:price)
  end

  def remainder_price(%Job{} = job) do
    job |> remainder_payment() |> Map.get(:price)
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

  def deposit_paid?(%Job{} = job) do
    job |> deposit_payment() |> PaymentSchedule.paid?()
  end

  def remainder_paid?(%Job{} = job) do
    job |> remainder_payment() |> PaymentSchedule.paid?()
  end

  def remainder_due_on(%Job{} = job) do
    job |> remainder_payment() |> Map.get(:due_at)
  end

  def deposit_paid_at(%Job{} = job) do
    job |> deposit_payment() |> Map.get(:paid_at)
  end

  def remainder_paid_at(%Job{} = job) do
    job |> remainder_payment() |> Map.get(:paid_at)
  end

  def deposit_payment(job) do
    job |> payment_schedules() |> Enum.at(0) || %PaymentSchedule{}
  end

  def remainder_payment(job) do
    job |> payment_schedules() |> Enum.at(-1) || %PaymentSchedule{}
  end

  def payment_schedules(job) do
    Repo.preload(job, [:payment_schedules])
    |> Map.get(:payment_schedules)
    |> Enum.sort_by(& &1.due_at)
  end
end
