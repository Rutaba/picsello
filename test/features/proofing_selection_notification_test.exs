defmodule Picsello.ProofingSelectionNotificationTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  alias Picsello.Repo
  alias Picsello.Cart.{Digital, Order}
  require Ecto.Query

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery, user: user} do
    proofing_album = insert(:proofing_album, %{gallery_id: gallery.id})
    photo_ids = insert_photo(%{gallery: gallery, album: proofing_album, total_photos: 2})
    organization = insert(:organization, user: user)
    client = insert(:client, organization: organization)
    package = insert(:package, organization: organization)
    job = insert(:lead, type: "wedding", client: client, package: package)

    order =
      insert(:order,
        gallery: gallery |> Repo.preload(:organization),
        album: proofing_album,
        placed_at: DateTime.utc_now(),
        digitals: [%Digital{photo_id: List.first(photo_ids), price: ~M[0]USD}]
      )

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok

    [
      job: job,
      proofing_album: proofing_album,
      organization: organization,
      photo_ids: photo_ids
    ]
  end

  feature "user receives next up card on home page", %{
    organization: organization,
    gallery: gallery,
    proofing_album: proofing_album,
    photo_ids: photo_ids,
    session: session
  } do
    order =
      insert(:order,
        gallery: gallery |> Repo.preload(:organization),
        album: proofing_album,
        placed_at: DateTime.utc_now(),
        digitals: [%Digital{photo_id: List.first(photo_ids), price: ~M[0]USD}]
      )

    orders = organization.id |> Picsello.Orders.get_all_proofing_album_orders()

    session
    |> assert_has(css("h1", text: "A client selected their proofs!"))
    |> assert_has(button("Download .CSV"))
  end
end
