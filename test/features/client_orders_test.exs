defmodule Picsello.ClientOrdersTest do
  use Picsello.FeatureCase, async: true
  import Ecto.Query, only: [from: 2]
  import Money.Sigils

  setup do
    Picsello.Test.WHCCCatalog.sync_catalog()
  end

  setup do
    photographer = insert(:user)

    gallery =
      insert(:gallery,
        job: insert(:lead, package: %{download_each_price: ~M[2500]USD}, user: photographer)
      )

    for category <- Picsello.Repo.all(Picsello.Category) do
      preview_photo = insert(:photo, gallery: gallery, preview_url: "/fake.jpg")

      insert(:gallery_product,
        category: category,
        preview_photo: preview_photo,
        gallery: gallery
      )
    end

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    [gallery: gallery]
  end

  def click_first_photo(session),
    do: force_simulate_click(session, css("#muuri-grid > div:first-child img"))

  setup :authenticated_gallery_client

  feature "get to editor", %{session: session, gallery: %{id: gallery_id} = gallery} do
    {gallery_product_id, whcc_product_id} =
      from(whcc_product in Picsello.Product,
        join: whcc_category in assoc(whcc_product, :category),
        join: gallery_product in assoc(whcc_category, :gallery_products),
        where: gallery_product.gallery_id == ^gallery_id,
        select: {gallery_product.id, whcc_product.whcc_id},
        limit: 1
      )
      |> Picsello.Repo.one()

    Picsello.MockWHCCClient
    |> Mox.stub(:editor, fn args ->
      url =
        args
        |> get_in(["redirects", "complete", "url"])
        |> URI.parse()
        |> Map.update!(:query, &String.replace(&1, "%EDITOR_ID%", "editor-id"))
        |> URI.to_string()

      %Picsello.WHCC.CreatedEditor{url: url}
    end)
    |> Mox.stub(:editor_details, fn _wat, "editor-id" ->
      %Picsello.WHCC.Editor.Details{
        product_id: whcc_product_id,
        selections: %{"size" => "6x9"},
        editor_id: "editor-id"
      }
    end)
    |> Mox.stub(:editor_export, fn _wat, "editor-id" ->
      %Picsello.WHCC.Editor.Export{
        items: [],
        order: %{},
        pricing: %{"totalOrderBasePrice" => 1.00, "code" => "USD"}
      }
    end)
    |> Mox.stub(:create_order, fn _account_id, _editor_id, _opts ->
      %Picsello.WHCC.Order.Created{total: "69"}
    end)

    Picsello.PhotoStorageMock |> Mox.stub(:path_to_url, & &1)

    session
    |> assert_text(gallery.name)
    |> click(link("View Gallery"))
    |> click_first_photo()
    |> assert_text("Select an option")
    |> find(css("*[data-testid^='product_option']", count: :any), fn options ->
      assert [
               {"Wall Displays", "$25.00"},
               {"Albums", "$50.00"},
               {"Books", "$45.00"},
               {"Ornaments", "$40.00"},
               {"Loose Prints", "$25.00"},
               {"Press Printed Cards", "$0.00"},
               {"Display Products", "$80.00"},
               {"Digital Download", "$25.00"}
             ] =
               options
               |> Enum.map(fn option ->
                 option
                 |> find(css("p", count: 2))
                 |> Enum.map(&Element.text/1)
                 |> List.to_tuple()
               end)
    end)
    |> click(css("button[phx-value-template-id='#{gallery_product_id}']"))
    |> click(button("Customize & buy"))
    |> assert_url_contains("cart")
    |> assert_text("Cart Review")
    |> click(button("Continue"))
    |> fill_in(text_field("Email address"), with: "client@example.com")
    |> fill_in(text_field("Name"), with: "brian")
    |> fill_in(text_field("Shipping address"), with: "123 w main st")
    |> fill_in(text_field("delivery_info_address_city"), with: "Tulsa")
    |> click(option("OK"))
    |> fill_in(text_field("delivery_info_address_zip"), with: "74104")
    |> wait_for_enabled_submit_button()
    |> click(button("Continue"))
    |> assert_has(button("Check out with Stripe"))
  end

  describe "digital downloads" do
    feature "add to cart", %{session: session, gallery: gallery} do
      gallery_path = current_path(session)

      session
      |> assert_text(gallery.name)
      |> click(link("View Gallery"))
      |> click_first_photo()
      |> assert_text("Select an option")
      |> click(button("Add to cart"))
      |> assert_has(link("cart", text: "1"))
      |> click_first_photo()
      |> assert_has(testid("product_option_digital_download", text: "In cart"))
      |> click(link("close"))
      |> click(link("cart"))
      |> find(css("*[data-testid^='digital-']"), fn cart_item ->
        cart_item
        |> assert_text("Digital download")
        |> assert_has(css("img[src='/fake.jpg']"))
        |> assert_text("$25.00")
        |> click(button("Delete"))
      end)
      |> assert_path(gallery_path)
      |> refute_has(link("cart"))
    end
  end

  @tag :skip
  feature "client reviews the placed order", %{session: session, gallery: gallery, order: order} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}/orders/#{order.number}")
    |> assert_text("My orders")
    |> assert_text("Order number #{order.number}")
    |> assert_text("Your order will be sent to:")
    |> assert_text(order.delivery_info.name)
    |> assert_text(order.delivery_info.address.addr1)
    |> assert_text(
      order.delivery_info.address.city <>
        ", " <> order.delivery_info.address.state <> " " <> order.delivery_info.address.zip
    )
  end
end
