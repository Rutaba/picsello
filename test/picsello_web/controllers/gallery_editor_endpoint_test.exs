defmodule PicselloWeb.GalleryEditorEndpointTest do
  use PicselloWeb.ConnCase, async: true
  import Ecto.Query
  import Money.Sigils

  alias Picsello.Galleries

  setup do
    Picsello.Test.WHCCCatalog.sync_catalog()
  end

  setup do
    photographer = insert(:user)
    gallery = insert(:gallery, job: insert(:lead, user: photographer))

    for category <- Picsello.Repo.all(Picsello.Category) do
      preview_photo = insert(:photo, gallery: gallery, preview_url: "fake.jpg")

      insert(:gallery_product,
        category: category,
        preview_photo: preview_photo,
        gallery: gallery
      )
    end

    [gallery: gallery]
  end

  describe "WHCC secondary url handling" do
    test "creates clone for editor and adds current one to the cart", %{
      conn: conn,
      gallery: gallery
    } do
      gallery_id = gallery.id
      new_editor_url = "http://cloned.url.net"

      {_, whcc_product_id} =
        from(whcc_product in Picsello.Product,
          join: whcc_category in assoc(whcc_product, :category),
          join: gallery_product in assoc(whcc_category, :gallery_products),
          where: gallery_product.gallery_id == ^gallery_id,
          select: {gallery_product.id, whcc_product.whcc_id},
          limit: 1
        )
        |> Picsello.Repo.one()

      Picsello.MockWHCCClient
      |> Mox.stub(:editor_details, fn _wat, "editor-id" ->
        build(:whcc_editor_details,
          product_id: whcc_product_id,
          selections: %{"size" => "6x9"},
          editor_id: "editor-id"
        )
      end)
      |> Mox.stub(:editors_export, fn _account_id, [%{id: "editor-id"}], _opts ->
        build(:whcc_editor_export, unit_base_price: ~M[100]USD)
      end)
      |> Mox.stub(:editor_clone, fn _wat, "editor-id" -> "clone-editor-id" end)
      |> Mox.stub(:get_existing_editor, fn _wat, id ->
        %Picsello.WHCC.CreatedEditor{url: new_editor_url, editor_id: id}
      end)
      |> Mox.stub(:create_order, fn _account_id, _export ->
        build(:whcc_order_created, total: ~M[69]USD)
      end)

      assert {:error, _} = Picsello.Cart.get_unconfirmed_order(gallery.id)

      conn =
        post(
          conn,
          "/gallery/#{gallery.client_link_hash}?clone=true&editorId=editor-id",
          %{
            "accountId" => Galleries.account_id(gallery)
          }
        )

      response = json_response(conn, 200)
      assert new_editor_url == response

      {:ok, order} = Picsello.Cart.get_unconfirmed_order(gallery.id)

      assert 1 == order |> Ecto.assoc(:products) |> Picsello.Repo.aggregate(:count)
    end
  end
end
