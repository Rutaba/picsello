defmodule Picsello.ClientOrdersTest do
  use Picsello.FeatureCase, async: true
  import Ecto.Query, only: [from: 2]
  import Money.Sigils
  alias Picsello.{Repo, Cart.Order, Package, Galleries.Photo}

  setup do
    Mox.verify_on_exit!()
    Picsello.Test.WHCCCatalog.sync_catalog()
  end

  setup do
    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")
    _photographer = insert(:user, organization: organization) |> onboard!()

    package = insert(:package, organization: organization, download_each_price: ~M[2500]USD)

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization),
            package: package
          )
      )

    insert(:watermark, gallery: gallery)

    for %{id: category_id} = category <- Picsello.Repo.all(Picsello.Category) do
      preview_photo =
        insert(:photo,
          gallery: gallery,
          preview_url: "/#{category_id}/preview.jpg",
          original_url: "/#{category_id}/original.jpg",
          watermarked_preview_url: "/#{category_id}/watermarked_preview.jpg",
          watermarked_url: "/#{category_id}/watermarked.jpg"
        )

      insert(:gallery_product,
        category: category,
        preview_photo: preview_photo,
        gallery: gallery
      )
    end

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    [gallery: gallery, organization: organization, package: package]
  end

  def click_photo(session, position) do
    session |> click(css("#muuri-grid .muuri-item-shown:nth-child(#{position}) *[id^='img']"))
  end

  setup :authenticated_gallery_client

  def payment_intent,
    do: %Stripe.PaymentIntent{
      status: "requires_payment_method",
      amount: 0,
      amount_capturable: 0,
      amount_received: 0,
      description: "something",
      application_fee_amount: 0
    }

  def stub_create_session(mock, %{
        connect_account: connect_account_id,
        session: session_id,
        payment_intent: payment_intent_id,
        amount: amount
      }) do
    test_pid = self()

    Mox.stub(mock, :create_session, fn %{
                                         success_url: success_url,
                                         payment_intent_data: payment_intent_data
                                       } = params,
                                       opts ->
      assert {:connect_account, connect_account_id} in opts
      success_url = URI.parse(success_url)
      assert %{"session_id" => "{CHECKOUT_SESSION_ID}"} = URI.decode_query(success_url.query)
      send(test_pid, {:checkout_link, params})

      {:ok,
       %{
         url:
           success_url
           |> Map.put(:query, URI.encode_query(%{"session_id" => session_id}))
           |> URI.to_string(),
         payment_intent:
           %{payment_intent() | id: payment_intent_id, amount: amount}
           |> Map.merge(payment_intent_data)
       }}
    end)
  end

  def stub_retrieve_session(mock, %{
        connect_account: connect_account_id,
        session: stripe_session_id,
        payment_intent: payment_intent_id
      }) do
    Mox.stub(mock, :retrieve_session, fn ^stripe_session_id,
                                         connect_account: ^connect_account_id ->
      order_number = Order |> Repo.one!() |> Order.number()

      {:ok,
       %Stripe.Session{
         id: stripe_session_id,
         payment_status: "unpaid",
         payment_intent: payment_intent_id,
         client_reference_id: "order_number_#{order_number}"
       }}
    end)
  end

  def stub_retrieve_payment_intent(mock, %{
        payment_intent: payment_intent_id,
        connect_account: account_id,
        amount: amount
      }) do
    Mox.expect(
      mock,
      :retrieve_payment_intent,
      fn ^payment_intent_id, connect_account: ^account_id ->
        {:ok,
         %{
           payment_intent()
           | id: payment_intent_id,
             status: "requires_capture",
             amount_capturable: amount,
             amount: amount
         }}
      end
    )
  end

  def stub_capture_payment_intent(mock, %{payment_intent: intent_id, connect_account: connect}) do
    Mox.expect(
      mock,
      :capture_payment_intent,
      fn ^intent_id, connect_account: ^connect ->
        {:ok, %{payment_intent() | id: intent_id, status: "succeeded"}}
      end
    )
  end

  feature "order product", %{
    session: session,
    gallery: %{id: gallery_id} = gallery,
    organization: organization
  } do
    {gallery_product_id, whcc_product_id, size} =
      from(whcc_product in Picsello.Product,
        join: whcc_category in assoc(whcc_product, :category),
        join: gallery_product in assoc(whcc_category, :gallery_products),
        where: gallery_product.gallery_id == ^gallery_id,
        select:
          {gallery_product.id, whcc_product.whcc_id,
           fragment(
             """
             jsonb_path_query(?, '$[*] \\? (@._id == "size")[0].attributes[0].id')
             """,
             whcc_product.attribute_categories
           )},
        limit: 1
      )
      |> Picsello.Repo.one()

    Picsello.MockWHCCClient
    |> Mox.stub(:editor, fn args ->
      assert %{
               "photos" => [%{"url" => preview_url, "printUrl" => print_url} | _],
               "redirects" => %{"complete" => %{"url" => complete_url}}
             } = args

      assert String.ends_with?(preview_url, "watermarked_preview.jpg")
      assert String.ends_with?(print_url, "original.jpg")

      url =
        complete_url
        |> URI.parse()
        |> Map.update!(:query, &String.replace(&1, "%EDITOR_ID%", "editor-id"))
        |> URI.to_string()

      %Picsello.WHCC.CreatedEditor{url: url}
    end)
    |> Mox.stub(:editor_details, fn _wat, "editor-id" ->
      build(:whcc_editor_details,
        product_id: whcc_product_id,
        selections: %{"size" => size, "quantity" => 1},
        editor_id: "editor-id"
      )
    end)
    |> Mox.stub(:editors_export, fn _account_id, [%{id: "editor-id", quantity: nil}], _opts ->
      build(:whcc_editor_export, unit_base_price: ~M[300]USD, order_sequence_number: 1)
    end)
    |> Mox.expect(:create_order, fn _account_id, _export ->
      {:ok, build(:whcc_order_created, total: ~M[69]USD, sequence_number: 1)}
    end)
    |> Mox.stub(:confirm_order, fn _account_id, _confirmation ->
      {:ok, :confirmed}
    end)

    %{stripe_account_id: connect_account_id} = organization

    Picsello.MockPayments
    |> stub_create_session(%{
      connect_account: connect_account_id,
      session: "stripe-session",
      payment_intent: "payment-intent-id",
      amount: 1000
    })
    |> stub_retrieve_session(%{
      connect_account: connect_account_id,
      session: "stripe-session",
      payment_intent: "payment-intent-id"
    })
    |> stub_retrieve_payment_intent(%{
      connect_account: connect_account_id,
      payment_intent: "payment-intent-id",
      amount: 1000
    })
    |> stub_capture_payment_intent(%{
      payment_intent: "payment-intent-id",
      connect_account: connect_account_id
    })

    Picsello.PhotoStorageMock |> Mox.stub(:path_to_url, & &1)

    session
    |> assert_text(gallery.name)
    |> click(css("a", text: "View Gallery"))
    |> assert_has(css("*[data-testid='products'] li", count: 7))
    |> click_photo(1)
    |> assert_text("Select an option")
    |> find(css("*[data-testid^='product_option']", count: :any), fn options ->
      assert [
               {"Wall Displays", "$25.00"},
               {"Albums", "$55.00"},
               {"Books", "$45.00"},
               {"Ornaments", "$40.00"},
               {"Loose Prints", "$25.00"},
               {"Press Printed Cards", "$5.00"},
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
    |> click(link("Continue"))
    |> fill_in(text_field("Email address"), with: "client@example.com")
    |> fill_in(text_field("Name"), with: "brian")
    |> fill_in(text_field("Shipping address"), with: "123 w main st")
    |> fill_in(text_field("delivery_info_address_city"), with: "Tulsa")
    |> click(option("OK"))
    |> fill_in(text_field("delivery_info_address_zip"), with: "74104")
    |> wait_for_enabled_submit_button()
    |> click(button("Check out with Stripe"))

    assert [%{errors: []}] = run_jobs()

    assert_receive(
      {:checkout_link,
       %{
         client_reference_id: "order_number_" <> _order_number,
         customer_email: "client@example.com",
         automatic_tax: %{enabled: true},
         line_items: [
           %{
             price_data: %{
               product_data: %{images: [_product_image], tax_code: "txcd_99999999"},
               unit_amount: 1000,
               tax_behavior: "exclusive"
             }
           }
         ]
       }}
    )

    session
    |> assert_has(css("h3", text: "Thank you for your order!"))
    |> click(link("My orders"))
    |> find(definition("Order total:"), &assert(Element.text(&1) == "$10.00"))
  end

  feature "client doesn't see products for non-US photographer", %{
    session: session,
    gallery: gallery
  } do
    Picsello.Repo.update_all(Picsello.Accounts.User,
      set: [
        onboarding: %Picsello.Onboardings.Onboarding{
          state: "Non-US",
          completed_at: DateTime.utc_now()
        }
      ]
    )

    session
    |> visit(current_url(session))
    |> assert_text(gallery.name)
    |> click(css("a", text: "View Gallery"))
    |> assert_has(css("*[data-testid='products'] li", count: 0))
    |> click_photo(1)
    |> assert_text("Select an option")
    |> find(css("*[data-testid^='product_option']", count: :any), fn options ->
      assert [{"Digital Download", "$25.00"}] =
               options
               |> Enum.map(fn option ->
                 option
                 |> find(css("p", count: 2))
                 |> Enum.map(&Element.text/1)
                 |> List.to_tuple()
               end)
    end)
  end

  describe "digital downloads" do
    feature "purchase single", %{session: session, organization: organization} do
      %{stripe_account_id: connect_account_id} = organization

      Picsello.MockPayments
      |> stub_create_session(%{
        connect_account: connect_account_id,
        session: "session-id",
        payment_intent: "payment-intent-id",
        amount: 2500
      })
      |> stub_retrieve_session(%{
        connect_account: connect_account_id,
        session: "session-id",
        payment_intent: "payment-intent-id"
      })
      |> stub_retrieve_payment_intent(%{
        connect_account: connect_account_id,
        payment_intent: "payment-intent-id",
        session: "session-id",
        amount: 2500
      })
      |> stub_capture_payment_intent(%{
        payment_intent: "payment-intent-id",
        connect_account: connect_account_id
      })

      gallery_path = current_path(session)

      session
      |> click(css("a", text: "View Gallery"))
      |> click_photo(1)
      |> assert_text("Select an option")
      |> click(button("Add to cart"))
      |> assert_has(link("cart", text: "1"))
      |> click_photo(1)
      |> assert_has(testid("product_option_digital_download", text: "In cart"))
      |> click(link("close"))
      |> click_photo(2)
      |> assert_text("Select an option")
      |> click(button("Add to cart"))
      |> assert_has(link("cart", text: "2"))
      |> click(link("cart"))
      |> assert_has(definition("Total", text: "$50.00"))
      |> find(css("*[data-testid^='digital-']", count: 2, at: 0), fn cart_item ->
        cart_item
        |> assert_text("Digital download")
        |> find(
          css("img"),
          fn img ->
            src = Element.attr(img, "src")
            assert String.ends_with?(src, "/watermarked_preview.jpg")
          end
        )
        |> assert_text("$25.00")
        |> click(button("Delete"))
      end)
      |> assert_has(definition("Total", text: "$25.00"))
      |> find(css("*[data-testid^='digital-']", count: 1, at: 0), fn cart_item ->
        cart_item
        |> assert_text("Digital download")
        |> assert_has(css("img[src$='/watermarked_preview.jpg']"))
        |> assert_text("$25.00")
        |> click(button("Delete"))
      end)
      |> assert_path(gallery_path)
      |> assert_has(css("*[title='cart']", text: "0"))
      |> click_photo(1)
      |> within_modal(&click(&1, button("Add to cart")))
      |> click(link("cart"))
      |> click(link("Continue"))
      |> assert_has(css("h2", text: "Enter digital delivery information"))
      |> assert_has(definition("Digital downloads (1)", text: "$25.00"))
      |> assert_has(definition("Total", text: "$25.00"))
      |> fill_in(text_field("Email"), with: "brian@example.com")
      |> fill_in(text_field("Name"), with: "Brian")
      |> refute_has(text_field("Shipping address"))
      |> wait_for_enabled_submit_button()
      |> click(button("Check out with Stripe"))

      assert [%{errors: []}] = run_jobs()

      order_number = Order |> Repo.one!() |> Order.number() |> to_string()

      assert_receive(
        {:checkout_link,
         %{
           client_reference_id: "order_number_" <> ^order_number,
           customer_email: "brian@example.com",
           automatic_tax: %{enabled: true},
           line_items: [
             %{
               price_data: %{
                 product_data: %{images: [product_image], tax_code: "txcd_10501000"},
                 unit_amount: 2500,
                 tax_behavior: "exclusive"
               }
             }
           ]
         }}
      )

      assert String.ends_with?(product_image, "watermarked_preview.jpg")

      session
      |> assert_has(css("h3", text: "Thank you for your order!"))
      |> assert_has(css("img[src$='/preview.jpg']"))
      |> assert_text("Digital download")
      |> assert_has(css("*[title='cart']", text: "0"))
      |> find(
        link("Download photos"),
        &assert(Element.attr(&1, "href") == session |> current_url() |> Path.join("zip"))
      )
      |> click(link("Home"))
      |> click_photo(1)
      |> assert_has(testid("product_option_digital_download", text: "Download"))
      |> click(link("close"))
      |> click(link("My orders"))
      |> find(definition("Order number:"), fn number ->
        session
        |> find(css("img"), fn img ->
          src = Element.attr(img, "src")
          assert String.ends_with?(src, "/preview.jpg")
        end)
        |> find(
          link("Download photos"),
          &assert(
            Element.attr(&1, "href") ==
              Path.join([current_url(session), Element.text(number), "zip"])
          )
        )
      end)
    end

    feature "with download credit", %{session: session} do
      Repo.update_all(Package, set: [download_count: 2])

      session
      |> visit(current_url(session))
      |> click(link("View Gallery"))
      |> click_photo(1)
      |> assert_has(definition("Download Credits", text: "2"))
      |> click(button("Add to cart"))
      |> assert_has(link("cart", text: "1"))
      |> click_photo(2)
      |> assert_has(definition("Download Credits", text: "1"))
      |> click(button("Add to cart"))
      |> click(link("cart", text: "2"))
      |> assert_has(definition("Total", text: "$0.00"))
      |> click(link("Home"))
      |> click_photo(3)
      |> refute_has(testid("download-credit"))
      |> click(button("Add to cart"))
      |> assert_has(link("cart", text: "3"))
      |> click(link("cart"))
      |> assert_has(definition("Total", text: "$25.00"))
      |> find(css("*[data-testid^='digital-']", count: 3, at: 0), fn cart_item ->
        cart_item
        |> assert_text("Digital download")
        |> assert_text("1 credit - $0.00")
      end)
      |> find(css("*[data-testid^='digital-']", count: 3, at: 1), fn cart_item ->
        cart_item
        |> assert_text("Digital download")
        |> assert_text("1 credit - $0.00")
      end)
      |> find(css("*[data-testid^='digital-']", count: 3, at: 2), fn cart_item ->
        cart_item
        |> assert_text("Digital download")
        |> assert_text("$25.00")
      end)
      |> assert_has(definition("Total", text: "$25.00"))
      |> click(link("Continue"))
      |> assert_has(definition("Digital downloads (3)", text: "$75.00"))
      |> assert_has(definition("Digital download credit (2)", text: "-$50"))
    end

    feature "purchase bundle", %{session: session, package: package, organization: organization} do
      %{stripe_account_id: connect_account_id} = organization
      assert ~M[5000]USD = package.buy_all

      Picsello.MockPayments
      |> stub_create_session(%{
        connect_account: connect_account_id,
        session: "session-id",
        payment_intent: "payment-intent-id",
        amount: 5000
      })
      |> stub_retrieve_session(%{
        connect_account: connect_account_id,
        session: "session-id",
        payment_intent: "payment-intent-id",
        amount: 5000
      })
      |> stub_retrieve_payment_intent(%{
        connect_account: connect_account_id,
        payment_intent: "payment-intent-id",
        session: "session-id",
        amount: 5000
      })
      |> stub_capture_payment_intent(%{
        payment_intent: "payment-intent-id",
        connect_account: connect_account_id
      })

      gallery_url = session |> current_url()
      photo1 = from(photo in Photo, order_by: photo.position, limit: 1) |> Repo.one!()

      session
      |> click(css("a", text: "View Gallery"))
      |> click(button("Buy now"))
      |> assert_text("Bundle - all digital downloads")
      |> within_modal(&assert_has(&1, css("img[src$='/watermarked_preview.jpg']", count: 3)))
      |> find(testid("product_option_bundle_download"), fn option ->
        option
        |> assert_text("All digital downloads")
        |> assert_text("$50.00")
        |> click(button("Add to cart"))
      end)
      |> assert_has(link("cart", text: "1"))
      |> click_photo(1)
      |> assert_has(testid("product_option_digital_download", text: "In cart"))
      |> click(link("close"))
      |> click(link("cart"))
      |> assert_has(definition("Total", text: "$50.00"))
      |> find(testid("bundle"), fn option ->
        option
        |> assert_text("Bundle - all digital downloads")
        |> assert_text("$50.00")
        |> click(button("Delete"))
      end)
      |> click_photo(1)
      |> within_modal(&click(&1, button("Add to cart")))
      |> assert_has(link("cart", text: "1"))
      |> click(button("Buy now"))
      |> find(testid("product_option_bundle_download"), fn option ->
        option
        |> click(button("Add to cart"))
      end)
      |> assert_has(link("cart", text: "1"))
      |> click(link("cart"))
      |> assert_has(definition("Total", text: "$50.00"))
      |> click(link("Continue"))
      |> assert_has(css("h2", text: "Enter digital delivery information"))
      |> assert_has(definition("Bundle - all digital downloads", text: "$50.00"))
      |> assert_has(definition("Total", text: "$50.00"))
      |> fill_in(text_field("Email"), with: "zach@example.com")
      |> fill_in(text_field("Name"), with: "Zach")
      |> wait_for_enabled_submit_button()
      |> click(button("Check out with Stripe"))

      assert [%{errors: []}] = run_jobs()

      order_number = Order |> Repo.one!() |> Order.number() |> to_string()

      assert_receive(
        {:checkout_link,
         %{
           client_reference_id: "order_number_" <> ^order_number,
           customer_email: "zach@example.com",
           line_items: [
             %{
               price_data: %{
                 product_data: %{images: [product_image], tax_code: "txcd_10501000"},
                 unit_amount: 5000,
                 tax_behavior: "exclusive"
               }
             }
           ]
         }}
      )

      assert String.ends_with?(product_image, "/watermarked_preview.jpg")

      session
      |> assert_has(css("h3", text: "Thank you for your order!"))
      |> assert_has(css("img[src$='/preview.jpg']", count: 3))
      |> assert_text("All digital downloads")
      |> assert_has(css("*[title='cart']", text: "0"))
      |> find(
        link("Download photos"),
        &assert(Element.attr(&1, "href") == session |> current_url() |> Path.join("zip"))
      )
      |> click(link("Home"))
      |> find(
        link("Download all photos"),
        &assert(Element.attr(&1, "href") == session |> current_url() |> Path.join("zip"))
      )
      |> click_photo(1)
      |> within_modal(fn modal ->
        modal
        |> assert_has(css("img[src$='/preview.jpg']"))
        |> assert_has(testid("product_option_digital_download", text: "Download"))
        |> find(
          link("Download"),
          &assert(
            Element.attr(&1, "href") == Path.join(gallery_url, "photos/#{photo1.id}/download")
          )
        )
        |> click(link("close"))
      end)
      |> refute_has(button("Buy now"))
      |> click(link("My orders"))
      |> find(definition("Order number:"), fn number ->
        session
        |> find(
          link("Download photos"),
          &assert(
            Element.attr(&1, "href") ==
              Path.join([current_url(session), Element.text(number), "zip"])
          )
        )
      end)
    end
  end
end
