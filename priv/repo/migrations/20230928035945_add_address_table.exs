defmodule Picsello.Repo.Migrations.AddAddressTable do
  use Ecto.Migration

  def up do
    create table(:addresses) do
      add(:address_line_1, :string)
      add(:address_line_2, :string)
      add(:state, :string)
      add(:zipcode, :string)
      add(:city, :string)

      add(:organization_id, references(:organizations, on_delete: :delete_all))
      add(:country_name, references(:countries, column: :name, type: :string))
    end
  end

  def down do
    drop(table(:addresses))
  end
end
