defmodule PicselloWeb.GalleryLive.SettingsTest do
  @moduledoc false
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @gallery_name "Diego Santos Weeding"

  describe "render" do
    setup do
      [gallery: insert(:gallery, %{name: @gallery_name})]
    end

    test "connected mount", %{conn: conn, gallery: gallery} do
      {:ok, _view, html} = live(conn, "/galleries/#{gallery.id}/settings")
      assert html |> Floki.text() =~ "Gallery Settings"
      assert html |> Floki.text() =~ "Gallery name"
      assert html |> Floki.text() =~ "Gallery password"
      assert html |> Floki.text() =~ "Custom watermark"
    end
  end
end
