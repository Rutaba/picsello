defmodule Picsello.DeleteGalleryWatermarkTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup do
    gallery = insert(:gallery, %{name: "Diego Santos Weeding"})

    [
      gallery: gallery,
      watermark: insert(:watermark, gallery: gallery, type: "text", text: "007Agency:)")
    ]
  end

  feature "user confirms deletion of watermark", %{
    session: session,
    gallery: gallery,
    watermark: watermark
  } do
    session
    |> visit("/galleries/#{gallery.id}")
    |> scroll_into_view(css("#galleryWatermark"))
    |> assert_has(css("p", text: watermark.text))
    |> click(button("remove watermark"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> assert_has(
      css("p",
        text: "Upload your logo and we’ll do the rest."
      )
    )
  end
end
