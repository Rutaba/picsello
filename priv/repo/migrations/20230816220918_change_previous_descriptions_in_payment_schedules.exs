defmodule Picsello.Repo.Migrations.ChangePreviousDescriptionsInPaymentSchedules do
  use Ecto.Migration

  def up do
    execute("UPDATE package_payment_schedules
             SET description = REPLACE(description, 'to To', 'To')
             WHERE description LIKE '%to To%'")
  end

  def down do
    execute("UPDATE package_payment_schedules
             SET description = REPLACE(description, 'To', 'to To')
             WHERE description LIKE '%To%'")
  end
end
