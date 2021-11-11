defmodule Picsello.Product do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  schema "products" do
    field :deleted_at, :utc_datetime
    field :position, :integer
    field :whcc_id, :string
    field :whcc_name, :string
    field :attribute_categories, {:array, :map}

    belongs_to(:category, Picsello.Category)

    timestamps(type: :utc_datetime)
  end

  def active, do: from(product in __MODULE__, where: is_nil(product.deleted_at))
end
