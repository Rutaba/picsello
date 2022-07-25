defmodule Picsello.Cart.DeliveryInfo do
  @moduledoc """
  Structure/schema to hold order delivery info
  """
  use Ecto.Schema
  import Ecto.Changeset
  import EctoCommons.EmailValidator
  alias __MODULE__.Address

  @primary_key false
  embedded_schema do
    field :name, :string
    field :email, :string
    embeds_one :address, Address
  end

  @type t :: %__MODULE__{
          name: String.t(),
          email: String.t(),
          address: Address.t()
        }

  def changeset(nil, attrs), do: changeset(%__MODULE__{}, attrs)

  def changeset(%Ecto.Changeset{} = delivery_info, %{"address_components" => _} = google_place) do
    delivery_info
    |> apply_changes()
    |> Map.put(:address, nil)
    |> changeset(%{"address" => google_place})
  end

  def changeset(delivery_info, attrs) do
    delivery_info
    |> cast(attrs, [:name, :email])
    |> cast_embed(:address)
    |> validate_required([:name, :email])
    |> validate_email(:email)
    |> validate_length(:name, min: 2, max: 30)
  end

  def selected_state(changeset) do
    changeset
    |> get_field(:address)
    |> then(& &1.state)
  end

  defmodule Address do
    @moduledoc "Structure/schema to hold order delivery info"
    use Ecto.Schema
    import Ecto.Changeset

    @states [
      "AL",
      "AK",
      "AS",
      "AZ",
      "AR",
      "CA",
      "CO",
      "CT",
      "DE",
      "DC",
      "FM",
      "FL",
      "GA",
      "GU",
      "HI",
      "ID",
      "IL",
      "IN",
      "IA",
      "KS",
      "KY",
      "LA",
      "ME",
      "MH",
      "MD",
      "MA",
      "MI",
      "MN",
      "MS",
      "MO",
      "MT",
      "NE",
      "NV",
      "NH",
      "NJ",
      "NM",
      "NY",
      "NC",
      "ND",
      "MP",
      "OH",
      "OK",
      "OR",
      "PW",
      "PA",
      "PR",
      "RI",
      "SC",
      "SD",
      "TN",
      "TX",
      "UT",
      "VT",
      "VI",
      "VA",
      "WA",
      "WV",
      "WI",
      "WY"
    ]

    @primary_key false
    embedded_schema do
      field :country, :string, default: "US"
      field :state, :string
      field :city, :string
      field :zip, :string
      field :addr1, :string
      field :addr2, :string
    end

    @type t :: %__MODULE__{
            addr1: String.t(),
            addr2: String.t(),
            city: String.t(),
            state: String.t(),
            zip: String.t()
          }

    @google_place_field_map %{
      "street_number" => "addr1",
      "route" => "addr1",
      "locality" => "city",
      "administrative_area_level_1" => "state",
      "postal_code" => "zip"
    }

    def changeset(address, %{"address_components" => components}) do
      attrs =
        for %{"short_name" => value, "types" => [type | _]} <- components,
            type in Map.keys(@google_place_field_map),
            reduce: %{} do
          addr ->
            Map.update(addr, Map.get(@google_place_field_map, type), value, &"#{&1} #{value}")
        end

      changeset(address, attrs)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:city, :state, :zip, :addr1, :addr2])
      |> validate_required([:city, :state, :zip, :addr1])
    end

    def states, do: @states
  end
end
