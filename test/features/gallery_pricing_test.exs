defmodule Picsello.GalleryPricingTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
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

    gallery_digital_pricing =
      insert(:gallery_digital_pricing, %{
        gallery: gallery,
        print_credits: Money.new(500_000),
        download_each_price: Money.new(20)
      })

    [gallery: gallery, gallery_digital_pricing: gallery_digital_pricing, package: package]
  end

  test "Pricing & print credit render", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/pricing")
    |> assert_text("Pricing & Print Credits")
    |> assert_has(css("#gallery-pricing"))
    |> assert_text("Digital Pricing")
    |> assert_has(css("#global-print-pricing"))
    |> assert_text("Global Print Pricing")
  end

  test "Pricing & print credit render Global Pricing", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/pricing")
    |> assert_has(css("#global-print-pricing"))
    |> assert_has(button("Edit global pricing"))
    |> scroll_to_bottom()
    |> click(button("Edit global pricing"))
    |> assert_url_contains("products")
    |> assert_text("Product Settings & Prices")
  end

  test "Pricing & Print Credits, renders confirmation for reseting to package pricing", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/pricing")
    |> assert_has(css("#reset-digital-pricing"))
    |> click(css("#reset-digital-pricing"))
    |> assert_text("You're resetting this gallery's pricing")
    |> assert_has(button("Yes, reset"))
    |> assert_has(button("Cancel"))
  end

  test "Pricing & Print Credits, resets to package pricing", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/pricing")
    |> assert_has(css("#reset-digital-pricing"))
    |> click(css("#reset-digital-pricing"))
    |> assert_text("You're resetting this gallery's pricing")
    |> assert_has(button("Yes, reset"))
    |> assert_has(button("Cancel"))
    |> click(button("Yes, reset"))
    |> assert_flash(:success, text: "Gallery pricing reset to package")
  end

  test "Pricing & Print Credits, renders gallery digital pricings", %{
    session: session,
    gallery: %{id: gallery_id},
    gallery_digital_pricing: gallery_digital_pricing
  } do
    session
    |> visit("/galleries/#{gallery_id}/pricing")
    |> assert_has(css("#gallery-pricing"))
    |> assert_text("Digital Pricing")
    |> assert_text("Here’s the pricing you have setup:")
    |> assert_has(button("Edit digital pricing & credits"))
    |> assert_has(css("p", text: "#{Money.to_string(gallery_digital_pricing.print_credits)}"))
    |> assert_has(css("p", text: "#{gallery_digital_pricing.download_count}"))
    |> assert_has(
      css("p", text: "#{Money.to_string(gallery_digital_pricing.download_each_price)}")
    )
  end

  test "Pricing & Print Credits, renders package price by reseting digital pricings", %{
    session: session,
    gallery: %{id: gallery_id},
    package: package
  } do
    session
    |> visit("/galleries/#{gallery_id}/pricing")
    |> assert_has(css("#reset-digital-pricing"))
    |> click(css("#reset-digital-pricing"))
    |> assert_text("You're resetting this gallery's pricing")
    |> assert_has(button("Yes, reset"))
    |> assert_has(button("Cancel"))
    |> click(button("Yes, reset"))
    |> assert_flash(:success, text: "Gallery pricing reset to package")
    |> assert_has(css("p", text: "#{Money.to_string(package.download_each_price)}"))
  end

  test "Pricing & Print Credits, edits digital pricing & credits", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/pricing")
    |> maximize_window()
    |> assert_has(css("#gallery-pricing"))
    |> assert_has(button("Edit digital pricing & credits"))
    |> click(button("Edit digital pricing & credits"))
    |> click(radio_button("Gallery includes Print Credits"))
    |> find(
      text_field("gallery_digital_pricing[print_credits]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$30"))
    )
    |> find(
      text_field("download[each_price]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> click(button("Save"))
    |> assert_flash(:success, text: "Gallery pricing updated")
    |> assert_has(css("p", text: "$30"))
    |> assert_has(css("p", text: "$2"))
  end
end
