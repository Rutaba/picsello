defmodule Picsello.Repo.Migrations.CreateShipmentZipcodes do
  use Ecto.Migration
  alias Picsello.Repo
  import Ecto.Query

  @csv_file "./priv/repo/zipcodes.csv"

  def up do
    create table(:shipment_zipcodes) do
      add(:zipcode, :integer, null: false)
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
          "INSERT INTO shipment_zipcodes (zipcode, das_type_id) VALUES (#{zipcode}, #{das_types[type]})"
        )
      end)
    end
  end

  def down do
    drop(table(:shipment_zipcodes))
  end
end
