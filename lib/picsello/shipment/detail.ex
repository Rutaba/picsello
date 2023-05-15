defmodule Picsello.Shipment.Detail do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Repo

  schema "shipment_details" do
    field :base_charge, Money.Ecto.Amount.Type
    field :das_carrier, Ecto.Enum, values: [:mail, :parcel]
    field :order_attribute_id, :integer
    field(:type, Ecto.Enum, values: [:economy_usps, :economy_trackable, :three_days, :one_day])

    field :upcharge, :map

    timestamps()
  end

  @fields ~w(type base_charge order_attribute_id das upcharge)a
  @doc false
  def changeset(shipment_detail, attrs) do
    shipment_detail
    |> cast(attrs, @fields)
    |> validate_required(@fields -- [:upcharge])
  end

  def all(), do: Repo.all(__MODULE__)
end
