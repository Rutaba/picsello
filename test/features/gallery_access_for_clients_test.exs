defmodule Picsello.GalleryAccessForClientsTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup do
    job = insert(:lead, type: "wedding", user: insert(:user)) |> promote_to_job()
    Mox.stub(Picsello.PhotoStorageMock, :get, fn _ -> {:error, nil} end)

    gallery = insert(:gallery, %{name: "Test Client Weeding", job: job})
    gallery_digital_pricing = insert(:gallery_digital_pricing, gallery: gallery)

    [gallery: gallery, gallery_digital_pricing: gallery_digital_pricing]
  end

  feature "client views password submit", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_has(css(".w-screen.h-screen.bg-white"))
    |> assert_has(css("#login_password", count: 1))
    |> assert_has(css("button", count: 1, text: "Submit"))
  end

  feature "client tries to log in", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_has(css(".w-screen.h-screen.bg-white"))
    |> fill_in(css("#login_email"), with: "testing@picsello.com")
    |> fill_in(css("#login_password"), with: "ThisIsAStrongP@ssw0rd")
    |> click(button("Submit"))
    |> assert_has(
      css("p",
        text: "Unfortunately, we do not recognize this password or incorrect email-format."
      )
    )
  end

  feature "client logs in", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_has(css(".w-screen.h-screen.bg-white"))
    |> fill_in(css("#login_email"), with: "testing@picsello.com")
    |> fill_in(css("#login_password"), with: gallery.password)
    |> click(button("Submit"))
    |> assert_path("/gallery/#{gallery.client_link_hash}")
    |> assert_has(css(".font-bold.text-2xl", text: "#{gallery.name}"))
  end
end
