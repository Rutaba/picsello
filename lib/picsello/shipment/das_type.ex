defmodule Picsello.Shipment.DasType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shipment_das_types" do
    field :mail_cost, :decimal
    field :parcel_cost, :decimal
    field :name, :string

    timestamps()
  end

  @fields [:type, :mail_cost, :parcel_cost]
  @doc false
  def changeset(das_cost, attrs) do
    das_cost
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end
end
