defmodule Picsello.Shipment.Detail do
  @moduledoc "schema to store different attributes involved in shipping calculation"
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Repo

  schema "shipment_details" do
    field :base_charge, Money.Ecto.Amount.Type
    field :das_carrier, Ecto.Enum, values: [:mail, :parcel]
    field :order_attribute_id, :integer
    field :type, Ecto.Enum, values: [:economy_usps, :economy_trackable, :three_days, :one_day]
    embeds_one :upcharge, __MODULE__.Upcharge, on_replace: :update

    timestamps()
  end

  defmodule Upcharge do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :default, :decimal
      field :wallart, :decimal, default: 0
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:default, :wallart])
      |> validate_required([:default])
    end
  end

  @fields ~w(type base_charge order_attribute_id das_carrier)a
  @doc false
  def changeset(shipment_detail, attrs \\ %{}) do
    shipment_detail
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> cast_embed(:upcharge, with: &Upcharge.changeset/2)
  end

  def all(), do: Repo.all(__MODULE__)
end
