defmodule Picsello.Galleries.GalleryProduct do
  @moduledoc false
  use Ecto.Schema
  use StructAccess
  alias Picsello.CategoryTemplate
  alias Picsello.Galleries.{Photo, Gallery}

  schema "gallery_products" do
    belongs_to(:category_template, CategoryTemplate)
    belongs_to(:preview_photo, Photo)
    belongs_to(:gallery, Gallery)

    timestamps()
  end
end
