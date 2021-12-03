defmodule Picsello.Design do
  @moduledoc "a whcc design"

  use Ecto.Schema
  import Ecto.Query, only: [from: 2]

  schema "designs" do
    field :api, :map
    field :attribute_categories, {:array, :map}
    field :deleted_at, :utc_datetime
    field :position, :integer
    field :whcc_id, :string
    field :whcc_name, :string

    belongs_to(:product, Picsello.Product)

    timestamps(type: :utc_datetime)
  end

  def active, do: from(product in __MODULE__, where: is_nil(product.deleted_at))
end
