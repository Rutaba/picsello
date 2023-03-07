defmodule Picsello.ClientBuysGreetingCardTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  setup do
    Mox.verify_on_exit!()
    Picsello.Test.WHCCCatalog.sync_catalog()
  end

  setup do
    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")

    insert(:user,
      organization: organization,
      stripe_customer_id: "photographer-stripe-customer-id"
    )
    |> onboard!()

    package =
      insert(:package,
        organization: organization,
        download_each_price: ~M[2500]USD,
        buy_all: ~M[5000]USD
      )

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization),
            package: package
          ),
        use_global: %{watermark: true, expiration: true, digital: true, products: true}
      )

    insert(:watermark, gallery: gallery)
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 3})

    for {%{id: category_id} = category, index} <-
          Enum.with_index(Picsello.Repo.all(Picsello.Category)) do
      preview_photo =
        insert(:photo,
          gallery: gallery,
          preview_url: "/#{category_id}/preview.jpg",
          original_url: "/#{category_id}/original.jpg",
          watermarked_preview_url: "/#{category_id}/watermarked_preview.jpg",
          watermarked_url: "/#{category_id}/watermarked.jpg",
          position: index + 1
        )

      insert(:gallery_product,
        category: category,
        preview_photo: preview_photo,
        gallery: gallery
      )

      global_gallery_product =
        insert(:global_gallery_product,
          category: category,
          organization: organization,
          markup: 100
        )

      if category.whcc_id == "h3GrtaTf5ipFicdrJ" do
        product = insert(:product, category: category)

        insert(:global_gallery_print_product,
          product: product,
          global_settings_gallery_product: global_gallery_product
        )
      end
    end

    Picsello.PhotoStorageMock
    |> Mox.stub(:path_to_url, & &1)
    |> Mox.stub(:get, &{:ok, %{name: &1}})

    Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "photographer-stripe-customer-id", _ ->
      {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
    end)

    [gallery: gallery, organization: organization, package: package, photo_ids: photo_ids]
  end

  setup :authenticated_gallery_client

  def click_filter_option(session, label_text, options \\ []) do
    options = Keyword.put_new(options, :visible, false)

    session
    |> find(css("label", count: :any, text: label_text), fn labels ->
      filter_label(labels, session, options, label_text)
    end)
  end

  def filter_label(labels, session, options, label_text) do
    labels
    |> Enum.find_value(fn label ->
      case Element.attr(label, "for") do
        <<_::binary-size(1)>> <> _ = id ->
          has?(session, css("input[type=checkbox]##{id}", options))

        _ ->
          has?(label, css("input[type=checkbox]", options))
      end && label
    end)
    |> case do
      nil -> "No labeled with text #{label_text} for a #{inspect(options)} checkbox"
      label -> Element.click(label)
    end
  end

  feature "filter designs", %{session: session, photo_ids: photo_ids, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(css("a", text: "View Gallery"))
    |> click(css("#img-#{List.first(photo_ids)}"))
    |> within_modal(fn modal ->
      modal
      |> assert_text("Select an option")
      |> click(testid("product_option", op: "^=", text: "Press Printed Cards"))
    end)
    |> assert_has(css("h1", text: "Choose occasion"))
    |> click(link("holiday"))
    |> assert_has(css("h1", text: "Holiday"))
    |> assert_text("Showing 5 of 5 designs")
    |> click(button("Foil"))
    |> click_filter_option("Has Foil", selected: false)
    |> assert_has(testid("pills", text: "Has Foil"))
    |> click_filter_option("Has Foil", selected: true)
    |> click(button("Orientation"))
    |> click_filter_option("Landscape", selected: false)
    |> assert_has(testid("pills", text: "Landscape"))
    |> click(button("Type"))
    |> click_filter_option("New")
    |> assert_has(testid("pills", text: "Landscape\nNew", visible: true))
    |> assert_text("Showing 1 of 5 designs")
    |> find(testid("pills", visible: true), fn pills ->
      pills
      |> assert_has(css("label", count: 3))
      |> click_filter_option("Landscape")
      |> assert_has(css("label", count: 2))
    end)
    |> click(button("Type"))
    |> assert_has(checkbox("new", visible: false, selected: true))
    |> find(testid("pills", visible: true), &click_filter_option(&1, "New"))
    |> assert_has(checkbox("new", visible: false, selected: false))
  end
end
