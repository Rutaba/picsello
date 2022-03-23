defmodule Picsello.ClientOrdersTest do
  use Picsello.FeatureCase, async: true
  import Ecto.Query, only: [from: 2]
  import Money.Sigils
  alias Picsello.{Repo, Cart.Order}

  setup do
    Picsello.Test.WHCCCatalog.sync_catalog()
  end

  setup do
    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")
    _photographer = insert(:user, organization: organization)

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization),
            package:
              insert(:package, organization: organization, download_each_price: ~M[2500]USD)
          )
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

    [gallery: gallery, organization: organization]
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
    feature "add to cart", %{session: session, gallery: gallery, organization: organization} do
      test_pid = self()

      %{stripe_account_id: connect_account_id} = organization

      Picsello.MockPayments
      |> Mox.stub(:checkout_link, fn %{success_url: success_url} = params,
                                     connect_account: ^connect_account_id ->
        success_url = URI.parse(success_url)
        assert %{"session_id" => "{CHECKOUT_SESSION_ID}"} = URI.decode_query(success_url.query)
        send(test_pid, {:checkout_link, params})

        {:ok,
         success_url
         |> Map.put(:query, URI.encode_query(%{"session_id" => "stripe-session-id"}))
         |> URI.to_string()}
      end)
      |> Mox.expect(:retrieve_session, fn "stripe-session-id",
                                          connect_account: ^connect_account_id ->
        order_number = Order |> Repo.one!() |> Order.number()

        {:ok,
         %Stripe.Session{
           id: "stripe-session-id",
           payment_status: "paid",
           client_reference_id: "order_number_#{order_number}"
         }}
      end)

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
      |> click_first_photo()
      |> click(button("Add to cart"))
      |> click(link("cart"))
      |> click(button("Continue"))
      |> assert_has(css("h2", text: "Enter digital delivery information"))
      |> assert_text("Digitals (1): $25.00")
      |> assert_text("Total: $25.00")
      |> fill_in(text_field("Email"), with: "brian@example.com")
      |> fill_in(text_field("Name"), with: "Brian")
      |> refute_has(text_field("Shipping address"))
      |> wait_for_enabled_submit_button()
      |> click(button("Continue"))

      order_number = Order |> Repo.one!() |> Order.number() |> to_string()

      assert_receive(
        {:checkout_link,
         %{
           client_reference_id: "order_number_" <> ^order_number,
           customer_email: "brian@example.com",
           line_items: [
             %{price_data: %{product_data: %{images: ["/fake.jpg"]}, unit_amount: 2500}}
           ]
         }}
      )

      session
      |> assert_has(css("h3", text: "Thank you for your order!"))
      |> assert_has(css("img[src='/fake.jpg']"))
      |> assert_text("Digital download")
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
