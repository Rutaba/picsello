defmodule Picsello.Address do
  @moduledoc "Store address of organization"
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.{Country, Organization}

  schema "addresses" do
    field(:address_line_1, :string)
    field(:address_line_2, :string)
    field(:city, :string)
    field(:state, :string)
    field(:zipcode, :string)

    belongs_to(:organization, Organization)

    belongs_to(:country, Country,
      references: :name,
      type: :string,
      foreign_key: :country_name
    )
  end

  def changeset(address, attrs) do
    address
    |> cast(attrs, [
      :address_line_1,
      :address_line_2,
      :city,
      :state,
      :zipcode,
      :country_name,
      :organization_id
    ])
    |> validate_required([:country_name, :state])
  end
end
