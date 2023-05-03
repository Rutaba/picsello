defmodule Mix.Tasks.UpdatePackagePaymentSchedules do
  @moduledoc false

  use Mix.Task
  import Ecto.Query, only: [from: 2]
  require Logger
  alias Picsello.{Repo, Package, Packages, PackagePaymentSchedule}

  @shortdoc "update global watermark paths"
  def run(_) do
    load_app()
    query = from(pps in PackagePaymentSchedule, group_by: pps.package_id, select: pps.package_id)

    from(p in Package,
      where: p.id not in subquery(query),
      preload: [:organization]
    )
    |> Repo.all()
    |> then(fn packages -> 
      packages_ids = Enum.map(packages, & &1.id)
      
      Logger.info("Records updated: #{inspect(packages_ids)}") 

      Ecto.Multi.new()
      |> Ecto.Multi.insert_all(:package_payment_schedules, PackagePaymentSchedule, fn _ ->
        Packages.make_package_payment_schedule(packages)
      end)
      |> Ecto.Multi.update_all(:templates, fn _ -> 
        from(p in Package, where: p.id in ^packages_ids, update: [set: [fixed: true, schedule_type: p.job_type]])
      end, [])
      |> Repo.transaction()  
    end)
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
