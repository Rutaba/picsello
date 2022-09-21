defmodule Picsello.ClientProofingAlbumTest do
  use Picsello.FeatureCase, async: true

  import Money.Sigils
  alias Picsello.{Repo, Package}
  alias Picsello.Galleries.Photo

  setup do
    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")
    insert(:user, organization: organization)
    package = insert(:package, organization: organization, download_each_price: ~M[2500]USD)

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization),
            package: package
          )
      )

    proofing_album = insert(:proofing_album, %{gallery_id: gallery.id})
    photo_ids = Enum.map(1..10, fn index ->
      %Photo{
        album_id: proofing_album.id,
        gallery_id: gallery.id,
        watermarked_preview_url: "/images/print.png",
        original_url: "/images/print.png",
        name: "/images/print.png",
        aspect_ratio: 2,
        position: index + 100,
        width: 487,
        height: 358
      }
      |> insert()
      |> Map.get(:id)
    end)

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    Repo.update_all(Package, set: [download_count: 2])

    [gallery: gallery, proofing_album: proofing_album, photo_ids: photo_ids]
  end

  setup :authenticated_proofing_album_client

  feature "Render proofing album", %{
    session: session,
    proofing_album: album,
    photo_ids: photo_ids
  } do
    session
    |> assert_has(css("h3", text: album.name))
    |> assert_has(css("#muuri-grid", count: 1))
    |> assert_has(css(".item", count: Enum.count(photo_ids)))
  end

  feature "credit & selections count, when no photo selected", %{session: session, photo_ids: photo_ids} do
    session
    |> click(css("#item-#{List.first(photo_ids)}"))
    |> assert_has(definition(" Digital Image Credits", text: "2 out of 2"))
    |> assert_has(testid("selections", text: "Selections 0"))
  end

  feature "credit & selections count, when one or more photos selected", %{session: session, photo_ids: photo_ids} do
    session
    |> click(css("#item-#{List.first(photo_ids)}"))
    |> assert_has(definition(" Digital Image Credits", text: "2 out of 2"))
    |> click(testid("select"))
    |> assert_has(testid("selections", text: "Selections 1"))
    |> assert_has(link("cart", text: "1"))
    |> click(testid("next"))
    |> click(testid("select"))
    |> assert_has(testid("selections", text: "Selections 2"))
  end

  feature "Dislay 'Add to cart' button, when no credit available", %{session: session, photo_ids: photo_ids} do
    session
    |> click(css("#item-#{List.first(photo_ids)}"))
    |> click(testid("product_option_digital_download"))
    |> click(testid("next"))
    |> click(testid("product_option_digital_download"))
    |> assert_has(definition(" Digital Image Credits", text: "0 out of 2"))
    |> click(testid("next"))
    |> assert_has(definition(" Digital Image Credits", text: "0 out of 2"))
    |> click(button("Add to cart"))
    |> assert_has(testid("selections", text: "Selections 3"))
  end

  feature "Review selections, when only credit is used", %{session: session, photo_ids: photo_ids} do
    session
    |> click(css("#item-#{List.first(photo_ids)}"))
    |> click(testid("product_option_digital_download"))
    |> click(testid("next"))
    |> click(testid("product_option_digital_download"))
    |> assert_has(testid("selections", text: "Selections 2"))
    |> click(link("close"))
    |> click(button("Review my Selections"))
    |> assert_has(definition("Total", text: "$0.00"))
    |> find(css("*[data-testid^='digital-']", count: 2, at: 0), fn cart_item ->
      cart_item
      |> assert_text("1 credit - $0.00")
    end)
    |> find(css("*[data-testid^='digital-']", count: 2, at: 1), fn cart_item ->
      cart_item
      |> assert_text("1 credit - $0.00")
    end)
  end

  feature "Review selections, when credit and price is used", %{session: session, photo_ids: photo_ids} do
    session
    |> click(css("#item-#{List.first(photo_ids)}"))
    |> click(testid("product_option_digital_download"))
    |> click(testid("next"))
    |> click(testid("product_option_digital_download"))
    |> assert_has(definition(" Digital Image Credits", text: "0 out of 2"))
    |> click(testid("next"))
    |> click(button("Add to cart"))
    |> assert_has(testid("selections", text: "Selections 3"))
    |> click(link("close"))
    |> click(button("Review my Selections"))
    |> assert_has(definition("Total", text: "$25.00"))
    |> find(css("*[data-testid^='digital-']", count: 3, at: 2), fn cart_item ->
      cart_item
      |> assert_text("$25.00")
    end)
  end
end
