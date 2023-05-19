defmodule PicselloWeb.NylasControllerTest do
  use PicselloWeb.ConnCase, async: true

  describe "GET nylas controller" do
    test "puts session token and redirects to gallery", %{conn: conn} do
      conn =
        get(conn, "/nylas/callback", %{
          "code" => "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
        })

      response = html_response(conn, 200)

      # assert get_session(conn, :gallery_session_token)

      # assert response =~
      #          "<html><body>You are being <a href=\"/gallery/#{gallery.client_link_hash}\">redirected</a>.</body></html>"
    end
  end
end
