defmodule Picsello.Shipment.Zipcode do
  use Ecto.Schema

  schema "shipment_zipcodes" do
    field :zipcode, :integer
    belongs_to :das_type, Picsello.Shipment.DasType
  end
end
