defmodule Picsello.Galleries.GalleryCategory do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.{Photo, Gallery, CategoryTemplate}

  schema "gallery_category" do
    belongs_to(:category_template, CategoryTemplate)
    belongs_to(:photo, Photo)
    belongs_to(:gallery, Gallery)

    timestamps()
  end

  @doc false
  def changeset(gallery_category, attrs) do
    gallery_category
    |> cast(attrs, [])
    |> validate_required([])
  end
end
