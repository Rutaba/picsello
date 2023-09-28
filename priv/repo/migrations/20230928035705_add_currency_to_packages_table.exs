defmodule Picsello.Repo.Migrations.AddCurrencyToPackagesTable do
  use Ecto.Migration

  def up do
    # alter table(:packages) do
    #   add(:currency, references(:currencies, type: :string, column: :code), default: "USD")
    # end
  end

  def down do
    alter table(:packages) do
      remove(:currency, references(:currencies, type: :string, column: :code), default: "USD")
    end
  end
end
