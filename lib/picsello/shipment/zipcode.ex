defmodule Picsello.Shipment.Zipcode do
  @moduledoc false
  use Ecto.Schema
  alias Picsello.Repo

  schema "shipment_zipcodes" do
    field :zipcode, :string
    belongs_to :das_type, Picsello.Shipment.DasType
  end

  def all(), do: Repo.all(__MODULE__)
end
