defmodule Picsello.Galleries.GalleryProduct do
  @moduledoc false
  use Ecto.Schema
  use StructAccess
  alias Picsello.Category
  alias Picsello.Galleries.{Photo, Gallery}

  schema "gallery_products" do
    belongs_to(:category, Category)
    belongs_to(:preview_photo, Photo)
    belongs_to(:gallery, Gallery)

    timestamps()
  end
end
