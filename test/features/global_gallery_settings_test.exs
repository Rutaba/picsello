defmodule Picsello.GSGalleryTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
  alias Picsello.{Galleries, Galleries.Watermark}
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Picsello.Repo

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    global_gallery_settings =
      insert(:global_gallery_settings,
        expiration_days: 50,
        organization_id: gallery.job.client.organization.id
      )

    [
      gallery: gallery,
      global_gallery_settings: global_gallery_settings
    ]
  end

  test "default global expiry is never expires", %{session: session} do
    session
    |> visit("/galleries")
    |> click(css("#gallery-settings"))
    |> find(Query.checkbox("neverExpire"))
    |> Element.selected?()
  end

  test "set expiration date of galleries", %{session: session} do
    session
    |> visit("/galleries")
    |> click(css("#gallery-settings"))
    |> click(css("#global_expiration_days_day"))
    |> fill_in(text_field("global_expiration_days_day"), with: "5")
    |> click(css("#global_expiration_days_month"))
    |> fill_in(text_field("global_expiration_days_month"), with: "2")
    |> click(css("#global_expiration_days_year"))
    |> fill_in(text_field("global_expiration_days_year"), with: "1")
    |> click(css("#saveGalleryExpiration"))
    |> click(button("Yes, set expiration date"))
    |> assert_flash(:success, text: "Setting Updated")
  end

  test "creates watermark", %{global_gallery_settings: global_gallery_settings, gallery: gallery} do
    global_watermark_change =
      GSGallery.text_watermark_change(nil, %{
        watermark_text: "Watermark"
      })

    global_gallery_settings
    |> Ecto.Changeset.change(global_watermark_change.changes)
    |> Repo.insert_or_update()

    attr =
      case global_watermark_change.changes.watermark_type do
        "image" ->
          %{
            name: global_gallery_settings.watermark_name,
            size: global_gallery_settings.watermark_size,
            type: "image"
          }

        "text" ->
          %{text: global_watermark_change.changes.watermark_text, type: "text"}
      end

    {:ok, %{watermark: watermark}} = Galleries.save_gallery_watermark(gallery, attr)
    global_gallery_settings = global_gallery_settings |> Repo.reload()
    assert %{watermark_text: "Watermark"} = global_gallery_settings
    assert %Watermark{} = watermark
    assert watermark.gallery_id == gallery.id
  end

  test "updates global watermark", %{
    global_gallery_settings: global_gallery_settings,
    gallery: gallery
  } do
    global_text_watermark_change =
      GSGallery.text_watermark_change(nil, %{
        watermark_text: "Watermark"
      })

    global_gallery_settings
    |> Ecto.Changeset.change(global_text_watermark_change.changes)
    |> Repo.insert_or_update()

    global_gallery_settings = global_gallery_settings |> Repo.reload()

    attr =
      case global_text_watermark_change.changes.watermark_type do
        "image" ->
          %{
            name: global_text_watermark_change.changes.watermark_name,
            size: global_text_watermark_change.changes.watermark_size,
            type: "image"
          }

        "text" ->
          %{text: global_text_watermark_change.changes.watermark_text, type: "text"}
      end

    {:ok, %{watermark: text_watermark}} = Galleries.save_gallery_watermark(gallery, attr)

    global_image_watermark_change =
      GSGallery.image_watermark_change(global_gallery_settings, %{
        watermark_name: "hex.png",
        watermark_size: 12_345
      })

    attr =
      case global_image_watermark_change.changes.watermark_type do
        "image" ->
          %{
            name: global_image_watermark_change.changes.watermark_name,
            size: global_image_watermark_change.changes.watermark_size,
            type: "image"
          }

        "text" ->
          %{text: global_image_watermark_change.changes.watermark_text, type: "text"}
      end

    {:ok, %{watermark: image_watermark}} = Galleries.save_gallery_watermark(gallery, attr)
    assert text_watermark.id == image_watermark.id
  end

  test "preloads watermark", %{gallery: gallery} do
    global_watermark_change =
      GSGallery.text_watermark_change(nil, %{
        watermark_text: "Watermark"
      })

    attr =
      case global_watermark_change.changes.watermark_type do
        "image" ->
          %{
            name: global_watermark_change.changes.watermark_name,
            size: global_watermark_change.changes.watermark_size,
            type: "image"
          }

        "text" ->
          %{text: global_watermark_change.changes.watermark_text, type: "text"}
      end

    {:ok, %{watermark: watermark}} = Galleries.save_gallery_watermark(gallery, attr)
    gallery = Galleries.load_watermark_in_gallery(gallery)
    assert watermark == gallery.watermark
  end
end
