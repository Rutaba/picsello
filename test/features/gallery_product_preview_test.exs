defmodule Picsello.GalleryProductPreviewTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Accounts.User}

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "cus_123", _ ->
      {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
    end)

    [products: products(gallery)]
  end

  def products(gallery, coming_soon \\ false) do
    for image <- [nil | Picsello.Category.frame_images()] do
      category = insert(:category, frame_image: image, coming_soon: coming_soon)
      insert(:product, category: category)
      insert(:gallery_product, category: category, gallery: gallery)
    end
  end

  describe "doesn't have payment method" do
    test "user sees warning and adds payment method", %{
      session: session,
      gallery: %{id: gallery_id},
      user: user,
      products: products
    } do
      test_pid = self()

      Mox.stub(Picsello.MockPayments, :create_billing_portal_session, fn params ->
        send(
          test_pid,
          {:portal_session_created, params}
        )

        {:ok,
         %{
           url:
             PicselloWeb.Endpoint.struct_url()
             |> Map.put(:fragment, "stripe-billing-portal")
             |> URI.to_string()
         }}
      end)

      session
      |> visit("/galleries/#{gallery_id}/product-previews")
      |> assert_text("It looks like you're missing a payment method.")
      |> click(button("Open Billing Portal"))
      |> assert_url_contains("stripe-billing-portal")

      return_url =
        Routes.gallery_product_preview_index_url(PicselloWeb.Endpoint, :index, gallery_id)

      assert_receive {:portal_session_created, %{return_url: ^return_url}}

      user |> User.assign_stripe_customer_changeset("cus_123") |> Repo.update!()

      session
      |> visit("/galleries/#{gallery_id}/product-previews")
      |> find(css("*[id^='/images']", count: length(products)))
    end
  end

  describe "has payment method" do
    setup %{user: user} do
      user = user |> User.assign_stripe_customer_changeset("cus_123") |> Repo.update!()

      [user: user]
    end

    test "Product Preview render", %{
      session: session,
      gallery: %{id: gallery_id},
      products: products
    } do
      session
      |> visit("/galleries/#{gallery_id}/product-previews")
      |> find(css("*[id^='/images']", count: length(products)))
    end

    test "Product Preview for Non-US photographer", %{
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
      |> visit("/galleries/#{gallery.id}/product-previews")
      |> assert_text("Product ordering is not available in your country yet.")
      |> find(css("*[id^='/images']", count: 0))
    end

    test "Product Preview render with coming soon", %{
      session: session,
      gallery: gallery
    } do
      products(gallery, true)

      session
      |> visit("/galleries/#{gallery.id}/product-previews")
      |> assert_has(css("button", text: "Edit product preview", count: 4))
      |> assert_has(css("button:disabled", text: "Coming soon!", count: 4))
    end

    test "Product Preview, edit product", %{
      session: session,
      gallery: %{id: gallery_id} = gallery,
      products: [%{id: product_id, category: category} | _]
    } do
      photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

      session
      |> visit("/galleries/#{gallery_id}/product-previews")
      |> click(css("#product-id-#{product_id}"))
      |> click(css("#photo-#{List.first(photo_ids)}"))
      |> click(button("Save"))
      |> assert_has(css("p", text: "#{category.name} preview successfully updated"))
    end

    test "Product Preview, set first photo of gallery as product previews", %{
      session: session,
      gallery: %{id: gallery_id} = gallery,
      products: products
    } do
      session
      |> visit("/galleries/#{gallery_id}/photos")
      |> assert_has(css("#dragDrop-upload-form-#{gallery_id} span", text: "Drag your images or"))
      |> visit("/galleries/#{gallery_id}/product-previews")
      |> find(css("*[id^='/images']", count: length(products)))

      assert current_path(session) == "/galleries/#{gallery_id}/product-previews"
      photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

      session
      |> visit("/galleries/#{gallery_id}/photos")
      |> assert_has(css(".item", count: length(photo_ids)))
      |> refute_has(css("#dragDrop-upload-form-#{gallery_id} span", text: "Drag your images or"))
      |> visit("/galleries/#{gallery_id}/product-previews")
      |> find(css("canvas[id='/images/print.png-/images/frames/album.png']", count: 1))
    end
  end

  test "Product Preview, 'edit product preview' is removed", %{
    session: session,
    gallery: %{id: gallery_id} = _gallery
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> scroll_to_bottom()
    |> assert_has(button("Edit product preview", visible: true, count: 4))
    |> find(checkbox("Product enabled to sell", visible: true, count: 4, at: 0), fn checkbox ->
      assert Element.selected?(checkbox)
    end)
    |> click(css("label", text: "Show product preview in gallery", count: 4, at: 0))
    |> assert_has(button("Edit product preview", visible: true, count: 3))
    |> click(css("label", text: "Product enabled to sell", count: 4, at: 1))
    |> assert_has(button("Edit product preview", visible: true, count: 2))
  end
end
