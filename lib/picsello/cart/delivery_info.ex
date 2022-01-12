defmodule Picsello.Cart.DeliveryInfo do
  @moduledoc """
  Structure/schema to hold order delivery info
  """
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :email, :string

    embeds_one :address, Address do
      field :state, :string
      field :city, :string
      field :zip, :string
      field :addr1, :string
      field :addr2, :string
    end
  end

  @email_regex ~r/^[^\s]+@[^\s]+\.[^\s]+$/

  def changeset(nil, attrs), do: changeset(%__MODULE__{}, attrs)

  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [:name, :email])
    |> cast_embed(:address, with: &address_changeset/2)
    |> validate_required([:name, :email])
    |> validate_format(:email, @email_regex)
    |> validate_length(:name, min: 2, max: 30)
  end

  def address_changeset(struct, attrs) do
    struct
    |> cast(attrs, [:city, :state, :zip, :addr1, :addr2])
    |> validate_required([:city, :state, :zip, :addr1])
    |> validate_address_data_relation()
  end

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

  defp ship_address() do
    %{
      "Name" => "Returns Department",
      "Addr1" => "3432 Denmark Ave",
      "Addr2" => "Suite 390",
      "City" => "Eagan",
      "State" => "MN",
      "Zip" => "55123",
      "Country" => "US",
      "Phone" => "8002525234"
    }
  end
end
