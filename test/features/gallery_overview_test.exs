defmodule Picsello.GalleryOverviewTest do
  use Picsello.FeatureCase, async: false

  alias Picsello.Galleries

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    [job: gallery.job]
  end

  def insert_order(gallery) do
    order =
      insert(:order,
        gallery: gallery,
        placed_at: DateTime.utc_now(),
        delivery_info: %Picsello.Cart.DeliveryInfo{}
      )

    insert(:digital,
      order: order,
      photo: insert(:photo, gallery: gallery, original_url: image_url())
    )

    order
  end

  feature "Validate preview gallery button", %{
    session: session,
    gallery: gallery
  } do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> assert_has(css("a[href*='/gallery/#{gallery.client_link_hash}']", text: "Preview gallery"))
  end

  feature "Validate and update gallery name", %{
    session: session,
    gallery: gallery
  } do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> fill_in(text_field("updateGalleryNameForm_name"), with: "")
    |> assert_has(css("button:disabled[id='saveGalleryName']"))
    |> fill_in(text_field("updateGalleryNameForm_name"),
      with: "TestTestTestTestTestTestTestTestTestTestTestTestTestTest"
    )
    |> assert_has(css("button:disabled[id='saveGalleryName']"))
    |> fill_in(text_field("updateGalleryNameForm_name"), with: "Test Wedding")
    |> wait_for_enabled_submit_button()
    |> click(button("saveGalleryName"))

    gallery = Galleries.get_gallery!(gallery.id)

    assert "Test Wedding" = gallery.name
  end

  feature "Reset gallery name", %{
    session: session,
    gallery: gallery
  } do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> fill_in(text_field("updateGalleryNameForm_name"), with: "Test Wedding")
    |> wait_for_enabled_submit_button()
    |> click(button("saveGalleryName"))
    |> click(button("Reset"))
    |> wait_for_enabled_submit_button()
    |> click(button("saveGalleryName"))

    gallery = Galleries.get_gallery!(gallery.id)

    refute "Test Wedding" == gallery.name
  end

  feature "Update gallery password", %{session: session, job: job} do
    gallery = insert(:gallery, %{job: job, password: "666666"})

    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 800)
    |> scroll_to_bottom()
    |> click(css("#togglePasswordVisibility"))
    |> click(css("#regeneratePasswordButton"))
    |> click(css("#togglePasswordVisibility"))

    updated_gallery = Galleries.get_gallery!(gallery.id)
    refute "666666" == updated_gallery.password
  end

  feature "Expiration date, set gallery to never expire", %{session: session, job: job} do
    gallery = insert(:gallery, %{job: job, expired_at: ~U[2021-02-01 12:00:00Z]})

    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 1000)
    |> scroll_into_view(css("#updateGalleryNeverExpire"))
    |> click(css("#updateGalleryNeverExpire"))
    |> click(css("#saveGalleryExpiration"))
    |> sleep(100)

    updated_gallery = Galleries.get_gallery!(gallery.id)

    assert nil == updated_gallery.expired_at
  end

  feature "Expiration date, set gallery expiry", %{session: session, gallery: gallery} do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 1000)
    |> scroll_into_view(css("#updateGalleryNeverExpire"))
    |> click(css("#updateGalleryNeverExpire"))
    |> find(select("date[month]"), &click(&1, option("January")))
    |> find(select("date[day]"), &click(&1, option("2")))
    |> find(select("date[year]"), &click(&1, option("2024")))
    |> click(css("#saveGalleryExpiration"))
    |> assert_text("Expiration date")

    updated_gallery = Galleries.get_gallery!(gallery.id)

    assert ~U[2024-01-02 12:00:00Z] == updated_gallery.expired_at
  end

  feature "Watermark, Set text watermark", %{session: session, gallery: gallery} do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 800)
    |> scroll_to_bottom()
    |> click(css("#watermark_popup"))
    |> click(css("#waterMarkText"))
    |> fill_in(text_field("textWatermarkForm_text"), with: "test watermark")
    |> within_modal(&click(&1, css("#saveWatermark")))
    |> assert_has(css("p", text: "test watermark"))
  end

  feature "Watermark, Delete watermark", %{session: session, gallery: gallery} do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 800)
    |> scroll_to_bottom()
    |> click(css("#watermark_popup"))
    |> click(css("#waterMarkText"))
    |> fill_in(text_field("textWatermarkForm_text"), with: "test watermark")
    |> within_modal(&click(&1, css("#saveWatermark")))
    |> assert_has(css("p", text: "test watermark"))
    |> click(button("remove watermark"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> refute_has(css("p", text: "test watermark"))
    |> assert_has(
      css("p",
        text: "Upload your logo and we’ll do the rest."
      )
    )
  end

  feature "Disable Gallery", %{session: session, gallery: gallery} do
    _order = insert_order(gallery)

    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 800)
    |> scroll_to_bottom()
    |> click(css("#deleteGalleryPopupButton"))
    |> within_modal(&click(&1, button("Yes, disable orders")))
    |> assert_url_contains("/galleries")
  end

  feature "Unable to update gallery settings when disabled", %{session: session, gallery: gallery} do
    _order = insert_order(gallery)
    {:ok, gallery} = Galleries.update_gallery(gallery, %{status: :disabled})

    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 800)
    |> assert_disabled(css(".galleryName"))
    |> assert_disabled(css("#galleryPasswordInput"))
    |> assert_disabled(select("date[month]"))
    |> assert_disabled(select("date[day]"))
    |> assert_disabled(select("date[year]"))
  end

  feature "Enable Gallery", %{session: session, gallery: gallery} do
    _order = insert_order(gallery)
    {:ok, gallery} = Galleries.update_gallery(gallery, %{status: :disabled})

    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 800)
    |> scroll_to_bottom()
    |> click(css("#deleteGalleryPopupButton"))
    |> within_modal(&click(&1, button("Yes, enable")))
    |> assert_url_contains("/galleries")
  end

  feature "Delete Gallery", %{session: session, job: job, gallery: gallery} do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> resize_window(1280, 800)
    |> scroll_to_bottom()
    |> click(css("#deleteGalleryPopupButton"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> assert_url_contains("/jobs/#{job.id}")
  end

  feature "Set first photo of gallery as cover photo", %{
    session: session,
    gallery: %{id: gallery_id} = gallery
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css("#dragDrop-upload-form-#{gallery_id} span", text: "Drag your images or"))
    |> visit("/galleries/#{gallery_id}")
    |> assert_has(css("#dragDrop-form span", text: "Drop image or"))

    assert current_path(session) == "/galleries/#{gallery_id}"
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: length(photo_ids)))
    |> visit("/galleries/#{gallery_id}")
    |> refute_has(css("#dragDrop-form span", text: "Drag image or"))
  end

  feature "Don't share gallery if photos not uploaded", %{
    session: session,
    gallery: gallery
  } do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> assert_has(css("button", count: 1, text: "Share gallery"))
    |> click(css("button", text: "Share gallery"))
    |> assert_has(css("p", text: "Please add photos to the gallery before sharing"))
  end
end
