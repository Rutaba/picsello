defmodule Picsello.Category do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  schema "categories" do
    field :deleted_at, :utc_datetime
    field :hidden, :boolean
    field :icon, :string
    field :name, :string
    field :position, :integer
    field :whcc_id, :string
    field :whcc_name, :string
    has_many(:products, Picsello.Product)

    timestamps(type: :utc_datetime)
  end

  def active, do: from(category in __MODULE__, where: is_nil(category.deleted_at))

  def changeset(category, attrs \\ %{}) do
    category
    |> cast(attrs, [:hidden, :icon, :name, :position])
    |> validate_required([:icon, :name, :position])
    |> unique_constraint(:position)
  end
end
