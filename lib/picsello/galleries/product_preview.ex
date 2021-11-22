defmodule Picsello.Galleries.ProductPreview do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.{Product, Photo}

  schema "product_previews" do
    field :index, :integer, default: 1
    belongs_to(:photo, Photo)
    belongs_to(:product, Product)

    timestamps()
  end

  @attrs [:index, :photo_id, :product_id]

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:photo_id)
  end
end
