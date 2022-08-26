defmodule Picsello.PackagePayments do
  @moduledoc "context module for packages"
  alias Picsello.{
    Repo,
    PackagePaymentSchedule,
    PackagePaymentPreset,
    PaymentSchedule
  }

  import Ecto.Query, warn: false

  @future_date ~D[2122-01-01]

  def get_package_presets(organization_id, job_type) do
    from(p in PackagePaymentPreset,
      where: p.organization_id == ^organization_id and p.job_type == ^job_type
    )
    |> Repo.one()
    |> Repo.preload(:package_payment_schedules)
  end

  def delete_schedules(package_id, payment_preset) do
    conditions = dynamic([p], p.package_id == ^package_id)

    conditions =
      if payment_preset,
        do: dynamic([p], p.package_payment_preset_id == ^payment_preset.id or ^conditions),
        else: conditions

    query = from(p in PackagePaymentSchedule, where: ^conditions)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_payments, query)
  end

  def delete_job_payment_schedules(nil), do: Ecto.Multi.new()

  def delete_job_payment_schedules(job_id) do
    query = from(p in PaymentSchedule, where: p.job_id == ^job_id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_job_payments, query)
  end

  def insert_job_payment_schedules(opts) do
    job_id = Map.get(opts, :job_id)
    multi = Ecto.Multi.new()

    if job_id do
      job_payment_schedules =
        opts.payment_schedules
        |> Enum.map(
          &%{
            job_id: job_id,
            price: get_price(&1, opts.total_price),
            due_at: get_due_at(&1) |> Timex.to_datetime(),
            description: get_description(&1),
            inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
            updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          }
        )

      multi
      |> Ecto.Multi.insert_all(
        :insert_job_payment_schedules,
        PaymentSchedule,
        job_payment_schedules
      )
    else
      multi
    end
  end

  defp get_description(%{interval: true, due_interval: due_interval}), do: due_interval

  defp get_description(%{
         due_at: nil,
         count_interval: count,
         time_interval: time,
         shoot_interval: shoot
       }) do
    count = count |> String.to_integer()
    count_interval = if count == 1, do: "1 #{time}", else: "#{count} #{time}s"
    "#{count_interval} #{shoot}"
  end

  defp get_description(%{due_at: due_at}), do: "Custom Payment At %{due_at}"

  defp get_price(%{price: nil, percentage: percentage}, total_price) do
    Money.divide(total_price, 100) |> List.first() |> Money.multiply(percentage)
  end

  defp get_price(%{price: price}, _), do: price

  defp get_due_at(
         %{
           due_interval: due_interval,
           interval: interval,
           shoot_date: shoot_date,
           schedule_date: schedule_date
         } = schedule
       ) do
    if shoot_date do
      schedule_date
    else
      if interval && String.contains?(due_interval, "To Book"),
        do: Timex.today(),
        else: shift_date(schedule)
    end
  end

  defp shift_date(%{schedule_date: schedule_date, shoot_date: shoot_date} = schedule) do
    due_at = Map.get(schedule, :due_at, nil)

    if due_at do
      due_at
    else
      diff = Date.diff(@future_date, schedule_date)
      Date.add(shoot_date, -diff)
    end
  end

  def insert_schedules(package, opts) do
    payment_preset = Map.get(opts, :payment_preset)

    case opts.action do
      :insert_preset ->
        preset = Map.take(package, [:schedule_type, :job_type, :fixed, :organization_id])
        changeset = PackagePaymentPreset.changeset(%PackagePaymentPreset{}, preset)

        opts.payment_schedules
        |> insert_payment_multi(changeset)

      :update_preset ->
        preset = Map.take(package, [:schedule_type, :job_type, :fixed, :organization_id])
        changeset = PackagePaymentPreset.changeset(payment_preset, preset)

        opts.payment_schedules
        |> insert_payment_multi(changeset)

      _ ->
        Ecto.Multi.new()
    end
    |> Ecto.Multi.merge(fn _ ->
      opts.payment_schedules
      |> Enum.map(&Map.put(&1, :package_id, package.id))
      |> insert_payment_multi()
    end)
  end

  defp insert_payment_multi(payment_schedules, changeset \\ nil) do
    payment_schedules = make_payment_schedules(payment_schedules)

    case Enum.empty?(payment_schedules) do
      true -> Ecto.Multi.new()
      _ -> upsert_schedules_and_preset(payment_schedules, changeset)
    end
  end

  defp upsert_schedules_and_preset(payment_schedules, changeset) do
    multi = Ecto.Multi.new()

    if changeset do
      multi
      |> Ecto.Multi.insert_or_update(:upsert_preset, changeset)
      |> Ecto.Multi.insert_all(
        :insert_schedule_presets,
        PackagePaymentSchedule,
        fn %{upsert_preset: %{id: preset_id}} ->
          payment_schedules |> Enum.map(&Map.put(&1, :package_payment_preset_id, preset_id))
        end
      )
    else
      multi
      |> Ecto.Multi.insert_all(:insert_schedules, PackagePaymentSchedule, payment_schedules)
    end
  end

  defp make_payment_schedules(payment_schedules) do
    now = current_datetime()

    payment_schedules
    |> Enum.map(fn schedule ->
      schedule
      |> Map.drop([
        :id,
        :shoot_date,
        :__meta__,
        :package,
        :package_payment_preset,
        :payment_field_index,
        :last_shoot_date
      ])
      |> Map.merge(%{inserted_at: now, updated_at: now})
    end)
  end

  defp current_datetime(), do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
