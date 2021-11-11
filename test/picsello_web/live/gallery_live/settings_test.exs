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

  describe "manage settings" do
    setup do
      [gallery: insert(:gallery, %{name: @gallery_name})]
    end

    test "gallery name [updates with valid input]", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      update_rendered =
        view
        |> element("#updateGalleryNameForm")
        |> render_change(%{gallery: %{name: "Client Weeding"}})

      assert update_rendered =~ "Client Weeding"
    end

    test "gallery name [update disabled with empty value]", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      update_rendered =
        view
        |> element("#updateGalleryNameForm")
        |> render_change(%{gallery: %{name: ""}})

      assert update_rendered =~
               "<button class=\"btn-primary mt-5 px-11 py-3.5 float-right cursor-pointer\" disabled=\"disabled\" phx-disable-with=\"Saving...\" type=\"submit\">Save</button><"
    end

    test "gallery name [update disabled with too long value]", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      update_rendered =
        view
        |> element("#updateGalleryNameForm")
        |> render_change(%{
          gallery: %{name: "TestTestTestTestTestTestTestTestTestTestTestTestTestTest"}
        })

      assert update_rendered =~
               "<button class=\"btn-primary mt-5 px-11 py-3.5 float-right cursor-pointer\" disabled=\"disabled\" phx-disable-with=\"Saving...\" type=\"submit\">Save</button><"
    end

    test "gallery name [resets gallery name]", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      update_rendered =
        view
        |> element("button", "Reset")
        |> render_click()

      refute update_rendered =~ gallery.name
    end
  end
end
