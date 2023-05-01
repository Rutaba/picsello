defmodule Picsello.GalleryPricingTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    :ok
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
end
