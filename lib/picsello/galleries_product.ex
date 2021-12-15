defmodule Picsello.GalleriesProduct do
  @moduledoc false

  require Logger
  alias Picsello.Repo
  alias Picsello.Category
  alias Picsello.CategoryTemplates
  alias Picsello.Galleries.GalleryProduct

  def get(fields) do
    Repo.get_by(GalleryProduct, fields)
    |> Repo.preload([:preview_photo, :category_template])
  end

  def get_template(fields) do
    Repo.get_by(Picsello.CategoryTemplates, fields)
  end

  def insert(row) do
    Repo.insert!(row)
  end

  def seed_templates() do
    frames = frames()

    unless Repo.aggregate(CategoryTemplates, :count) > 4 do
      Enum.each(frames, fn row ->
        length = Repo.aggregate(Category, :count)

        result =
          Repo.get_by(Category, %{name: row.category_name})

        case result do
          %{id: category_id} ->
            Repo.insert!(%CategoryTemplates{
              name: row.name,
              corners: row.corners,
              category_id: category_id
            })

          x ->
            Logger.error("category_template seed was not inserted. Probably Category table is empty. #{x}")
        end
      end)
    end
  end

  def frames() do
    [
      %{name: "card_blank.png", category_name: "Loose Prints",
        corners: [0, 0, 0, 0, 0, 0, 0, 0]},
      %{name: "album_transparency.png", category_name: "Albums",
        corners: [800, 715, 1720, 715, 800, 1620, 1720, 1620]},
      %{name: "card_envelope.png", category_name: "Press Printed Cards",
        corners: [1650, 610, 3100, 610, 1650, 2620, 3100, 2620]},
      %{name: "frame_transparency.png", category_name: "Books",
        corners: [550, 550, 2110, 550, 550, 1600, 2110, 1600]}
    ]
  end
end
