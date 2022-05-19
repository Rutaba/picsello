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

  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [:name, :email])
    |> cast_embed(:address, with: &Address.changeset/2)
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
      State: nil,
      AL: "AL",
      AK: "AK",
      AS: "AS",
      AZ: "AZ",
      AR: "AR",
      CA: "CA",
      CO: "CO",
      CT: "CT",
      DE: "DE",
      DC: "DC",
      FM: "FM",
      FL: "FL",
      GA: "GA",
      GU: "GU",
      HI: "HI",
      ID: "ID",
      IL: "IL",
      IN: "IN",
      IA: "IA",
      KS: "KS",
      KY: "KY",
      LA: "LA",
      ME: "ME",
      MH: "MH",
      MD: "MD",
      MA: "MA",
      MI: "MI",
      MN: "MN",
      MS: "MS",
      MO: "MO",
      MT: "MT",
      NE: "NE",
      NV: "NV",
      NH: "NH",
      NJ: "NJ",
      NM: "NM",
      NY: "NY",
      NC: "NC",
      ND: "ND",
      MP: "MP",
      OH: "OH",
      OK: "OK",
      OR: "OR",
      PW: "PW",
      PA: "PA",
      PR: "PR",
      RI: "RI",
      SC: "SC",
      SD: "SD",
      TN: "TN",
      TX: "TX",
      UT: "UT",
      VT: "VT",
      VI: "VI",
      VA: "VA",
      WA: "WA",
      WV: "WV",
      WI: "WI",
      WY: "WY"
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

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:city, :state, :zip, :addr1, :addr2])
      |> validate_required([:city, :state, :zip, :addr1])
      |> validate_address_data_relation()
    end

    def states, do: @states

    defp validate_address_data_relation(changeset) do
      validate_change(changeset, :zip, fn :zip, zip ->
        with {:ok, %{city: city, state: state}} <- ExZipcodes.lookup(zip),
             {:state, :equal} <- compare_zip_change(changeset, :state, state),
             {:city, :equal} <- compare_zip_change(changeset, :city, city) do
          []
        else
          {:error, reason} -> [zip: reason]
          error -> [error]
        end
      end)
    end

    defp compare_zip_change(changeset, field, change) do
      if get_field(changeset, field) == change do
        {field, :equal}
      else
        {field, "do not fit the zip"}
      end
    end
  end
end
