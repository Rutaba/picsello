defmodule Picsello.Galleries.GalleryProduct do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Category
  alias Picsello.Galleries.{Photo, Gallery}

  schema "gallery_products" do
    belongs_to(:category, Category)
    belongs_to(:photo, Photo)
    belongs_to(:gallery, Gallery)

    timestamps()
  end

  @doc false
  def changeset(gallery_product, attrs) do
    gallery_product
    |> cast(attrs, [])
    |> validate_required([])
  end
end
