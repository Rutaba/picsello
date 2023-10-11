defmodule Picsello.Repo.Migrations.UpdatePaymentDescription do
  use Ecto.Migration

  def up do
    # TODO remove this call and write own method within this migration
    payment_types =
      Picsello.Packages.get_payment_defaults() |> Map.values() |> List.flatten() |> Enum.uniq()

    Enum.each(payment_types, fn type ->
      execute("UPDATE package_payment_schedules
      SET description = REPLACE(description, 'to #{type}', '#{type}')
      WHERE description LIKE '%to #{type}%'")

      execute("UPDATE payment_schedules
      SET description = REPLACE(description, 'to #{type}', '#{type}')
      WHERE description LIKE '%to #{type}%'")
    end)
  end

  def down do
    payment_types =
      Picsello.Packages.get_payment_defaults() |> Map.values() |> List.flatten() |> Enum.uniq()

    Enum.each(payment_types, fn type ->
      execute("UPDATE package_payment_schedules
      SET description = REPLACE(description, '#{type}', 'to #{type}')
      WHERE description LIKE '%to #{type}%'")

      execute("UPDATE payment_schedules
      SET description = REPLACE(description, '#{type}', 'to #{type}')
      WHERE description LIKE '%#{type}%'")
    end)
  end
end
