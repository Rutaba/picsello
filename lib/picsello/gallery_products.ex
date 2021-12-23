defmodule Picsello.GalleryProducts do
  @moduledoc false

  require Logger
  alias Picsello.Repo
  alias Picsello.Category
  alias Picsello.CategoryTemplate
  alias Picsello.Galleries.GalleryProduct

  def get(fields) do
    Repo.get_by(GalleryProduct, fields)
    |> Repo.preload([:preview_photo, :category_template])
  end
end
