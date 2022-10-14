defmodule Picsello.Repo.Migrations.AddPaymentFieldsToPackages do
  use Ecto.Migration

  @table :packages
  def change do
    alter table(@table) do
      add(:schedule_type, :string)
      add(:fixed, :boolean)
    end
  end
end
