defmodule PicselloWeb.GallerySessionControllerTest do
  use PicselloWeb.ConnCase, async: true

  setup do
    %{gallery: insert(:gallery, %{name: "Diego Santos Weeding"})}
  end

  describe "POST /gallery/:hash/login" do
    test "puts session token and redirects to gallery", %{conn: conn, gallery: gallery} do
      conn =
        post(conn, "/gallery/#{gallery.client_link_hash}/gallery/login", %{
          "login" => %{"session_token" => "token"}
        })

      response = html_response(conn, 302)

      assert get_session(conn, :gallery_session_token)

      assert response =~
               "<html><body>You are being <a href=\"/gallery/#{gallery.client_link_hash}\">redirected</a>.</body></html>"
    end
  end
end
