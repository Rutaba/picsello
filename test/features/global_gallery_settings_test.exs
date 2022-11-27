defmodule Picsello.GlobalGallerySettingsTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
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

  test "set expiration date of galleries", %{session: session, gallery: gallery} do
    session
    |> visit("/galleries")
    |> click(css("#gallery-settings"))
    |> click(css("#day"))
    |> click(option("19"))
    |> click(css("#month > option:nth-child(12)"))
    |> click(css("#year > option:nth-child(2)"))
    |> click(css("#saveGalleryExpiration"))
    |> click(button("Yes, set expiration date"))
    |> assert_flash(:success, text: "Setting Updated")
  end

  test "set expiration date of galleries to never expires", %{
    session: session,
    gallery: gallery,
    global_gallery_settings: global_gallery_settings
  } do
    gallery |> Ecto.Changeset.change(%{expired_at: ~U[2022-11-15 18:53:19Z]}) |> Repo.update!()
    gallery = gallery |> Repo.reload()

    session
    |> visit("/galleries")
    |> click(css("#gallery-settings"))
    |> click(css("#neverExpire"))
    |> click(css("#saveGalleryExpiration"))
    |> click(button("Yes, set galleries to never expire"))

    gallery = gallery |> Repo.reload()
    global_gallery_settings = global_gallery_settings |> Repo.reload()
    assert %{expired_at: nil} = gallery
    assert %{expiration_days: 0} = global_gallery_settings
  end
end
