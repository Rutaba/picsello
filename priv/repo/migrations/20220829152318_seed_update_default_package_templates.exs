defmodule Picsello.Repo.Migrations.SeedUpdateDefaultPackageTemplates do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]
  alias Picsello.Repo

  def change do
    query =
      from p in "packages",
        where: not is_nil(p.job_type),
        select: %{
          id: p.id,
          job_type: p.job_type,
          base_price: p.base_price,
          base_multiplier: p.base_multiplier
        }

    Repo.all(query)
    |> Enum.reduce(0, fn package, acc ->
      payment_defaults =
        PicselloWeb.PackageLive.WizardComponent.get_payment_defaults(package.job_type, true)

      count = length(payment_defaults)

      presets =
        Enum.with_index(
          payment_defaults,
          fn default, index ->
            %{
              id: acc + (index + 1),
              package_id: package.id,
              price: get_price(package, count, index) * 100,
              description: "$#{get_price(package, count, index)} to #{default}",
              schedule_date: "3022-01-01 00:00:00",
              interval: true,
              due_interval: default,
              inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
              updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            }
          end
        )

      execute("""
      update packages set fixed = true, schedule_type = '#{package.job_type}' where id = #{package.id};
      """)

      Enum.map(presets, fn preset ->
        execute("""
        INSERT INTO package_payment_schedules (package_id, price, description, schedule_date, interval, due_interval, inserted_at, updated_at) VALUES (#{preset.package_id}, #{preset.price}, '#{preset.description}', '#{preset.schedule_date}', #{preset.interval}, '#{preset.due_interval}', '#{preset.inserted_at}', '#{preset.updated_at}');
        """)
      end)

      acc + count
    end)
  end

  defp get_price(
         %{base_multiplier: base_multiplier, base_price: base_price},
         presets_count,
         index
       ) do
    base_price = if(base_price, do: base_price, else: 0)

    amount =
      Decimal.mult(base_price, base_multiplier)
      |> Decimal.round(0, :floor)
      |> Decimal.to_integer()

    total_price = div(amount, 100)

    remainder = rem(total_price, presets_count)
    amount = if remainder == 0, do: total_price, else: total_price - remainder

    if index + 1 == presets_count do
      amount / presets_count + remainder
    else
      amount / presets_count
    end
    |> Kernel.trunc()
  end
end
