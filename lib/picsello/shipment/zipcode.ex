defmodule Picsello.Shipment.Zipcode do
  use Ecto.Schema

  schema "shipment_zipcodes" do
    field :zipcode, :string
    belongs_to :das_type, Picsello.Shipment.DasType
  end
end
