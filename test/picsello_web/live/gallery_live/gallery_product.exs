defmodule PicselloWeb.GalleryLive.GalleryProductTest do
  @moduledoc false

  use Picsello.FeatureCase, async: true

  alias Picsello.Repo
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.GalleryProduct
  alias Picsello.Galleries.Photo
  alias Picsello.Category
  alias Picsello.CategoryTemplates
  require Logger

  setup do
    unless Repo.aggregate(Category, :count) == 4 do
      Enum.each(frames(), fn row ->
        length = Repo.aggregate(Category, :count)

        category =
          Repo.insert(%Category{
            name: "example_category",
            icon: "example_icon",
            position: length,
            whcc_id: Integer.to_string(length),
            whcc_name: "example_name"
          })

        case category do
          {:ok, %{id: category_id}} ->
            Repo.insert!(%CategoryTemplates{
              name: row.name,
              corners: row.corners,
              category_id: category_id
            })

          x ->
            Logger.error("category_template seed was not inserted. #{x}")
        end
      end)
    end

    :ok
  end

  setup :onboarded
  setup :authenticated

  test "redirect from galleries", %{session: session} do
    %{gallery_id: id} = set_gallery_product()

    session
    |> visit("/galleries/#{id}")
    |> click(css(".prod-link0"))
    |> find(css(".item-content"))
  end

  test "save preview gallery product", %{session: session} do
    %{id: g_product_id, gallery_id: gallery_id} = set_gallery_product()

    session
    |> visit("/galleries/#{gallery_id}/product/#{g_product_id}")
    |> click(css(".item-content"))
    |> click(css(".save-button"))

    %{preview_photo: %{name: url}} =
      Repo.get_by(GalleryProduct, %{id: g_product_id}) |> Repo.preload([:preview_photo])

    assert "card_blank.png" == url
  end

  def set_gallery_product() do
    %{id: job_id} = insert(:lead)
    %{id: id} = insert(%Gallery{name: "testGalleryName", job_id: job_id})
    photo_url = "card_blank.png"

    insert(%Photo{
      gallery_id: id,
      preview_url: photo_url,
      original_url: photo_url,
      name: photo_url,
      position: 1
    })

    insert(%GalleryProduct{gallery_id: id, category_template_id: 1})
  end

  def frames() do
    [
      %{name: "card_blank.png", corners: [0, 0, 0, 0, 0, 0, 0, 0]},
      %{name: "album_transparency.png", corners: [800, 715, 1720, 715, 800, 1620, 1720, 1620]},
      %{name: "card_envelope.png", corners: [1650, 610, 3100, 610, 1650, 2620, 3100, 2620]},
      %{name: "frame_transperancy.png", corners: [550, 550, 2110, 550, 550, 1600, 2110, 1600]}
    ]
  end
end
