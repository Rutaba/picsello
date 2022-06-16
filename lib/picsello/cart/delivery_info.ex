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
        {field, "does not match the zip code"}
      end
    end
  end
end
