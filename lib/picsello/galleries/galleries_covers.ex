defmodule Picsello.Galleries.GalleriesCovers do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.{Photo, Gallery, CategoryTemplate}

  schema "galleries_covers" do
    belongs_to(:category_template_id, CategoryTemplate)
    belongs_to(:photo, Photo)
    belongs_to(:gallery, Gallery)

    timestamps()
  end

  @doc false
  def changeset(gallery_products, attrs) do
    gallery_products
    |> cast(attrs, [])
    |> validate_required([])
  end
end
