defmodule PicselloWeb.GalleryLive.GalleryProductTest do
  @moduledoc false

  use Picsello.FeatureCase, async: true

  alias Picsello.Repo
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.GalleryProduct
  alias Picsello.Galleries.Photo
  alias Picsello.Category
  alias Picsello.CategoryTemplate
  require Logger

  setup do
    unless Repo.aggregate(Category, :count) == 4 do
      frames = Picsello.CategoryTemplate.frames()

      Enum.each(frames, fn row ->
        length = Repo.aggregate(Category, :count)

        category =
          Repo.insert(%Category{
            name: row.category_name,
            icon: "example_icon",
            position: length,
            whcc_id: Integer.to_string(length),
            whcc_name: "example_name"
          })

        case category do
          {:ok, %{id: category_id}} ->
            Repo.insert(%CategoryTemplate{
              name: row.name,
              corners: row.corners,
              price: row.price,
              category_id: category_id
            })

          x ->
            Logger.error("category_template seed was not inserted. #{x}")
        end
      end)
    end

    :ok
  end

  setup do
    [gallery: insert(:gallery, %{name: "Test Client Weeding"})]
  end

  setup :onboarded
  setup :authenticated

  test "redirect from galleries", %{session: session} do
    %{gallery_id: id} = set_gallery_product()
    frame = Picsello.CategoryTemplate.frames() |> List.first()
    %{id: template_id} = Repo.get_by(Picsello.CategoryTemplates, %{name: frame.name})

    session
    |> visit("/galleries/#{id}")
    |> click(css(".prod-link#{template_id}"))
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

  test "grid load", %{session: session, gallery: %{id: gallery_id, client_link_hash: hash}} do
    photos = :lists.map(fn _ -> :rand.uniform(999_999) end, :lists.seq(1, 22))

    Enum.map(photos, &Map.get(insert_photo(gallery_id, "/images/tmp/#{&1}.png"), :id))

    session
    |> visit("/galleries/#{gallery_id}")

    session
    |> visit("/gallery/#{hash}/login")
    |> fill_in(css("#login_password"), with: "123456")
    |> has_text?("Test Client Weeding")

  end

  def insert_photo(gallery_id, photo_url) do
    insert(%Photo{
      gallery_id: gallery_id,
      preview_url: photo_url,
      original_url: photo_url,
      name: photo_url,
      position: 1
    })
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

    template = Repo.all(CategoryTemplate) |> hd

    insert(%GalleryProduct{gallery_id: id, category_template_id: template.id})
  end
end
