defmodule Picsello.GalleryDashboardCardAndViewTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    album = insert(:album, %{gallery_id: gallery.id})
    proofing_album = insert(:proofing_album, %{gallery_id: gallery.id})
    photo_ids = insert_photo(%{gallery: gallery, album: album, total_photos: 20})

    insert_photo(%{gallery: gallery, album: proofing_album, total_photos: 1})
    insert(:email_preset, type: :gallery, state: :proofs_send_link)

    [
      album: album,
      photo_ids: photo_ids,
      photos_count: length(photo_ids),
      proofing_album: proofing_album
    ]
  end

  feature "gallery card is present on the dashboard and gallery-view is working as intended", %{
    session: session,
    gallery: gallery
  } do
    visit_homepage(session)
    |> homepage_assertions_for_gallery_card()
    |> visit_view_all_galleries()
    |> gallerypage_assertions()
    |> upload_photos_redirect_to_gallery_details(gallery)
    |> copy_link_copies_the_gallery_link_to_clipboard()
    |> menu_button_click_opens_the_dropdown()
    |> edit_button_redirects_to_gallery_details(gallery)
    |> go_to_job_redirects_to_job_details()
    |> send_email_opens_email_modal()
    |> delete_button_deletes_the_selected_gallery()
    |> assertions_for_no_galleries_page()
  end

  defp visit_homepage(session) do
    session
    |> visit("/")
  end

  defp homepage_assertions_for_gallery_card(session) do
    session
    |> assert_has(testid("gallery-card"))
    |> assert_text("Galleries")
    |> assert_has(button("Create a gallery"))
    |> assert_has(button("View all galleries"))
  end

  defp visit_view_all_galleries(session) do
    session
    |> click(button("View all galleries"))
    |> assert_url_contains("galleries")
  end

  defp gallerypage_assertions(session) do
    session
    |> assert_text("Your Galleries")
    |> assert_has(testid("create-a-gallery"))
    |> assert_text("Gallery Details")
    |> assert_text("Actions")
    |> assert_has(link("Upload photos"))
    |> assert_has(testid("copy-link"))
    |> assert_has(css("#menu-button", count: 1))
  end

  defp upload_photos_redirect_to_gallery_details(session, gallery) do
    session
    |> click(link("Upload photos"))
    |> assert_url_contains("/galleries/#{gallery.id}")
    |> assert_text("Overview")
    |> assert_text("Photos")
    |> assert_text("Product previews")
    |> visit("/galleries")
  end

  defp copy_link_copies_the_gallery_link_to_clipboard(session) do
    session
    |> click(testid("copy-link"))
    |> assert_text("Copied!")
  end

  defp menu_button_click_opens_the_dropdown(session) do
    session
    |> click(css("#menu-button"))
    |> assert_has(link("Edit"))
    |> assert_has(link("Go to Job"))
    |> assert_has(css("#send-email-link"))
    |> assert_has(css("#delete-link"))
  end

  defp edit_button_redirects_to_gallery_details(session, gallery) do
    session
    |> click(link("Edit"))
    |> assert_url_contains("/galleries/#{gallery.id}")
    |> assert_text("Overview")
    |> assert_text("Photos")
    |> assert_text("Product previews")
    |> visit("/galleries")
    |> click(css("#menu-button"))
  end

  defp go_to_job_redirects_to_job_details(session) do
    session
    |> click(link("Go to Job"))
    |> assert_text("Details & communications")
    |> assert_text("Gallery & Orders")
    |> assert_text("Shoot details")
    |> assert_text("Booking details")
    |> visit("/galleries")
    |> click(css("#menu-button"))
  end

  defp send_email_opens_email_modal(session) do
    session
    |> click(css("#send-email-link"))
    |> assert_text("Send an email")
    |> click(button("Cancel"))
    |> click(css("#send-email-link"))
    |> fill_in(css("#client_message_subject"), with: "Test subject")
    |> fill_in(css(".ql-editor"), with: "Test message")
    |> wait_for_enabled_submit_button()
    |> click(button("Send"))
    |> assert_text("Thank you! Your message has been sent. We’ll be in touch with you soon.")
    |> click(button("Close"))
  end

  defp delete_button_deletes_the_selected_gallery(session) do
    session
    |> click(css("#delete-link"))
    |> click(button("Yes, delete"))
  end

  defp assertions_for_no_galleries_page(session) do
    session
    |> assert_text("Your Galleries")
    |> assert_text("Oh hey!")
    |> assert_text("You don't have any galleries at the moment.")
    |> assert_has(link("Create a gallery"))
  end
end
