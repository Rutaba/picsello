defmodule Picsello.GalleryOverviewTest do
  use Picsello.FeatureCase, async: false
  use Oban.Testing, repo: Picsello.Repo

  alias Picsello.Galleries
  alias PicselloWeb.GalleryLive.Settings.ExpirationDateComponent

  setup :authenticated
  setup :onboarded
  setup :authenticated_gallery

  feature "Validate and update gallery name", %{
    session: session,
    gallery: gallery
  } do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> fill_in(text_field("updateGalleryNameForm_name"), with: "")
    |> assert_has(css("button:disabled[id='saveGalleryName']"))
    |> fill_in(text_field("updateGalleryNameForm_name"), with: "TestTestTestTestTestTestTestTestTestTestTestTestTestTest")
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

  feature "Update gallery password", %{session: session} do
    gallery = insert(:gallery, %{password: "666666"})

    session
    |> visit("/galleries/#{gallery.id}/")
    |> scroll_into_view(css("#galleryPasswordInput"))
    |> click(css("#togglePasswordVisibility"))
    |> click(css("#regeneratePasswordButton"))
    |> click(css("#togglePasswordVisibility"))

    updated_gallery = Galleries.get_gallery!(gallery.id)
    refute "666666" == updated_gallery.password
  end

  feature "Expiration date, set gallery to never expire", %{session: session} do
    gallery = insert(:gallery, %{expired_at: ~U[2021-02-01 12:00:00Z]})

    session
    |> visit("/galleries/#{gallery.id}/")
    |> scroll_into_view(css("#expiration_component"))
    |> click(checkbox("neverExpire"))
    |> click(css("#saveGalleryExpiration"))

    updated_gallery = Galleries.get_gallery!(gallery.id)
    never_date = ExpirationDateComponent.never_date()

    assert never_date == updated_gallery.expired_at
  end

  feature "Expiration date, set gallery expiry", %{session: session} do
    gallery = insert(:gallery)

    session
    |> visit("/galleries/#{gallery.id}/")
    |> scroll_into_view(css("#expiration_component"))
    |> find(css("#updateGalleryExpirationForm_month"), &click(&1, option("January")))
    |> find(css("#updateGalleryExpirationForm_day"), &click(&1, option("2")))
    |> find(css("#updateGalleryExpirationForm_year"), &click(&1, option("2023")))
    |> click(css("#saveGalleryExpiration"))

    updated_gallery = Galleries.get_gallery!(gallery.id)

    assert ~U[2023-01-02 12:00:00Z] == updated_gallery.expired_at
  end

  feature "Watermark, Set text watermark", %{session: session, gallery: gallery} do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> scroll_into_view(css("#galleryWatermark"))
    |> click(css("#openCustomWatermarkPopupButton"))
    |> click(css("#waterMarkText"))
    |> fill_in(text_field("textWatermarkForm_text"), with: "test watermark")
    |> within_modal(&click(&1, css("#saveWatermark")))
    |> assert_has(css("p", text: "test watermark"))
  end

  feature "Watermark, Delete text watermark", %{session: session, gallery: gallery} do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> scroll_into_view(css("#galleryWatermark"))
    |> click(css("#openCustomWatermarkPopupButton"))
    |> click(css("#waterMarkText"))
    |> fill_in(text_field("textWatermarkForm_text"), with: "test watermark")
    |> within_modal(&click(&1, css("#saveWatermark")))
    |> assert_has(css("p", text: "test watermark"))
    |> click(button("remove watermark"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> refute_has(css("p", text: "test watermark"))
  end

  feature "Delete Gallery", %{session: session, gallery: gallery} do
    session
    |> visit("/galleries/#{gallery.id}/")
    |> scroll_into_view(css("#deleteGallery"))
    |> click(css("#deleteGalleryPopupButton"))
    |> within_modal(&click(&1, button("Yes, delete")))
  end
end
