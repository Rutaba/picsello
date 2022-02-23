defmodule PicselloWeb.GalleryLive.GalleryProductTest do
  @moduledoc false

  use Picsello.FeatureCase, async: true

  alias Picsello.Repo
  alias Picsello.Galleries.Photo

  setup do
    Enum.each(Picsello.Category.frame_images(), fn frame_image ->
      insert(:product, category: insert(:category, frame_image: frame_image))
    end)

    :ok
  end

  setup do
    [gallery: insert(:gallery, %{name: "Test Client Wedding"})]
  end

  setup :onboarded
  setup :authenticated

  test "redirect from galleries", %{session: session} do
    %{gallery_id: id} = set_gallery_product()
    frame = Picsello.Category.frame_images() |> hd
    %{id: category_id} = Repo.get_by(Picsello.Category, frame_image: frame)

    session
    |> visit("/galleries/#{id}")
    |> click(css(".prod-link#{category_id}"))
    |> find(css(".item-content"))
  end

  test "grid load", %{session: session, gallery: %{id: gallery_id, client_link_hash: hash}} do
    photos = :lists.map(fn _ -> :rand.uniform(999_999) end, :lists.seq(1, 22))

    Enum.map(photos, &Map.get(insert_photo(gallery_id, "/images/tmp/#{&1}.png"), :id))

    session
    |> visit("/galleries/#{gallery_id}")

    session
    |> visit("/gallery/#{hash}/login")
    |> fill_in(css("#login_password"), with: "123456")
    |> has_text?("Test Client Wedding")
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
    gallery = insert(:gallery, name: "testGalleryName", job: insert(:lead))
    photo_url = "card_blank.png"

    insert(:photo,
      gallery: gallery,
      preview_url: photo_url,
      original_url: photo_url,
      name: photo_url,
      position: 1
    )

    category = Picsello.Category |> Repo.all() |> hd

    insert(:gallery_product, gallery: gallery, category: category)
  end
end
