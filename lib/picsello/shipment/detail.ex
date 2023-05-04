defmodule Picsello.Shipment.Detail do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shipment_details" do
    field :base_charge, Money.Ecto.Amount.Type
    field :das_carrier, Ecto.Enum, values: [:mail, :parcel]
    field :order_attribute_id, :integer
    field :type, :string
    field :upcharge, :map

    timestamps()
  end

  @fields ~w(type base_charge order_attribute_id das upcharge)
  @doc false
  def changeset(shipment_detail, attrs) do
    shipment_detail
    |> cast(attrs, @fields)
    |> validate_required(@fields -- [:upcharge])
  end
end
