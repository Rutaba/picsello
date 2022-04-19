defmodule Picsello.DeleteGalleryWatermarkTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup do
    gallery = insert(:gallery, %{name: "Diego Santos Weeding"})
    watermark = insert(:watermark, gallery_id: gallery.id, type: "text", text: "007Agency:)")

    %{gallery: gallery, watermark: watermark}
  end

  feature "user confirms deletion of watermark", %{
    session: session,
    gallery: gallery,
    watermark: watermark
  } do
    session
    |> visit("/galleries/#{gallery.id}/settings")
    |> assert_has(css("p", text: watermark.text))
    |> click(css("button#deleteWatermarkBtn"))
    |> click(css("button", text: "Yes, delete"))
    |> assert_has(
      css("p",
        text: "Upload your logo and we’ll do the rest."
      )
    )
  end
end
