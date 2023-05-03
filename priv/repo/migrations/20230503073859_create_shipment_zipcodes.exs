defmodule Picsello.Repo.Migrations.CreateShipmentZipcodes do
  use Ecto.Migration
  alias Picsello.Repo
  import Ecto.Query

  @csv_file "./priv/repo/zipcodes.csv"

  def up do
    create table(:shipment_zipcodes) do
<<<<<<< HEAD
      add(:zipcode, :string, null: false)
=======
      add(:zipcode, :integer, null: false)
>>>>>>> 61c1b549d (Add migrations with seed for shipment details, das types, zipcodes)
      add(:das_type_id, references(:shipment_das_types, on_delete: :nothing), null: false)
    end

    if File.exists?(@csv_file) do
      das_types =
        from(q in "shipment_das_types", select: [:name, :id])
        |> Repo.all()
        |> Map.new(&{&1.name, &1.id})

      @csv_file
      |> File.stream!()
      |> Stream.drop(1)
      |> CSV.decode!()
      |> Enum.each(fn [zipcode, type] ->
        execute(
<<<<<<< HEAD
          "INSERT INTO shipment_zipcodes (zipcode, das_type_id) VALUES ('#{zipcode}', #{das_types[type]})"
=======
          "INSERT INTO shipment_zipcodes (zipcode, das_type_id) VALUES (#{zipcode}, #{das_types[type]})"
>>>>>>> 61c1b549d (Add migrations with seed for shipment details, das types, zipcodes)
        )
      end)
    end
  end

  def down do
    drop(table(:shipment_zipcodes))
  end
end
