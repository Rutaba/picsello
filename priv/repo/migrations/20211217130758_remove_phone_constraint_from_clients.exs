defmodule Picsello.Repo.Migrations.RemovePhoneConstraintFromClients do
  use Ecto.Migration

  def up do
    alter table(:clients) do
      modify(:phone, :string, null: true)
    end
  end

  def down do
    execute("update clients set phone = '(555) 555-5555' where phone is null;")

    alter table(:clients) do
      modify(:phone, :string, null: false)
    end
  end
end
