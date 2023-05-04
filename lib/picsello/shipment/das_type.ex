defmodule Picsello.Shipment.DasType do
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.Shipment.{DasType, Zipcode}
  alias Picsello.Repo
  import Ecto.Query

  schema "shipment_das_types" do
    field :mail_cost, Money.Ecto.Amount.Type
    field :parcel_cost, Money.Ecto.Amount.Type
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

  def get_by_zipcode(zipcode) do
    from(dt in DasType,
      join: zipcode in Zipcode,
      on: dt.id == zipcode.das_type_id,
      where: zipcode.zipcode == ^zipcode,
      limit: 1
    )
    |> Repo.one()
  end
end
