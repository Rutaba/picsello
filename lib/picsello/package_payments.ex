defmodule Picsello.PackagePayments do
  @moduledoc "context module for packages"
  alias Picsello.{
    Repo,
    PackagePaymentSchedule,
    PackagePaymentPreset
  }
  import Ecto.Query, warn: false

  def get_package_presets(organization_id, job_type) do
    from(p in PackagePaymentPreset, where: p.organization_id == ^organization_id and p.job_type == ^job_type)
    |> Repo.one()
    |> Repo.preload(:package_payment_schedules)
  end

  def delete_schedules(package_id, payment_preset) do
    conditions = dynamic([p], p.package_id == ^package_id)
    conditions = if payment_preset, do: dynamic([p], p.package_payment_preset_id == ^payment_preset.id or ^conditions), else: conditions
    
    query = from(p in PackagePaymentSchedule, where: ^conditions)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_payments, query)
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
      
      _ -> Ecto.Multi.new()
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
      _ -> upsert_schedules_and_preset(changeset, payment_schedules)
    end    
  end
  
  defp upsert_schedules_and_preset(changeset, payment_schedules) do
    multi = Ecto.Multi.new()

    if changeset do
      multi
      |> Ecto.Multi.insert_or_update(:upsert_preset, changeset)
      |> Ecto.Multi.insert_all(:insert_schedule_presets, PackagePaymentSchedule, fn %{upsert_preset: %{id: preset_id}} ->
        payment_schedules |> Enum.map(&Map.put(&1, :package_payment_preset_id, preset_id))
      end)
    else
      
      multi
      |> Ecto.Multi.insert_all(:insert_schedules, PackagePaymentSchedule, payment_schedules)
    end
  end

  defp make_payment_schedules(payment_schedules) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    payment_schedules |> Enum.map(fn schedule ->
      schedule
      |> Map.drop([:id, :shoot_date, :__meta__, :package, :package_payment_preset])
      |> Map.merge(%{inserted_at: now, updated_at: now})
    end)
  end
end
