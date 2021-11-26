defmodule Picsello.Galleries.GalleriesCovers do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.{Photo, Gallery}

  schema "galleries_covers" do
    field :category_template_id, :id
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
