defmodule Picsello.GalleryAccessForClientsTest do
  use Picsello.FeatureCase, async: true

  setup do
    [gallery: insert(:gallery, %{name: "Test Client Weeding"})]
  end 
  
  feature "client views password submit", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_has(css(".w-screen.h-screen.bg-black"))
    |> assert_has(css("h1", text: "Enter the password to view the gallery"))
    |> assert_has(css("#login_password", count: 1))
    |> assert_has(css("button", count: 1, text: "Submit"))
  end

  feature "client tries to log in", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_has(css(".w-screen.h-screen.bg-black"))
    |> fill_in(css("#login_password"), with: "ThisIsAStrongP@ssw0rd")
    |> click(button("Submit"))
    |> assert_has(css("p", text: "Unfortunately, we do not recognize this password."))
  end

  feature "client logs in", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_has(css(".w-screen.h-screen.bg-black"))
    |> fill_in(css("#login_password"), with: gallery.password)
    |> click(button("Submit"))
    |> assert_path("/gallery/#{gallery.client_link_hash}")
    |> assert_has(css(".font-bold.text-3xl", text: "#{gallery.name} Gallery"))
  end
end
