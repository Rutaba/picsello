defmodule PicselloWeb.GalleryLive.SettingsTest do
  @moduledoc false
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    [gallery: insert(:gallery, %{name: "Diego Santos Weeding"})]
  end

  describe "general render" do
    test "connected mount", %{conn: conn, gallery: gallery} do
      {:ok, _view, html} = live(conn, "/galleries/#{gallery.id}/settings")
      assert html |> Floki.text() =~ "Gallery Settings"
      assert html |> Floki.text() =~ "Gallery name"
      assert html |> Floki.text() =~ "Gallery password"
      assert html |> Floki.text() =~ "Custom watermark"
    end
  end

  describe "gallery name updates" do
    test "updates with valid input", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      update_rendered =
        view
        |> element("#updateGalleryNameForm")
        |> render_change(%{gallery: %{name: "Client Weeding"}})

      assert update_rendered =~ "Client Weeding"
    end

    test "update disabled with empty value", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      update_rendered =
        view
        |> element("#updateGalleryNameForm")
        |> render_change(%{gallery: %{name: ""}})

      assert update_rendered =~
               "<button class=\"btn-primary mt-5 px-11 py-3.5 float-right cursor-pointer\" disabled=\"disabled\" phx-disable-with=\"Saving...\" type=\"submit\">Save</button><"
    end

    test "update disabled with too long value", %{conn: conn, gallery: gallery} do
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

    test "resets gallery name", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      update_rendered =
        view
        |> element("button", "Reset")
        |> render_click()

      refute update_rendered =~ gallery.name
    end
  end

  describe "manage password" do
    test "render password input", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")
      password_input = element(view, "#galleryPasswordInput") |> render
      
      assert password_input =~ "disabled=\"disabled\""
      assert password_input =~ "type=\"password\""
    end

    test "shows password when on click", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")
      
      view 
      |> element("#togglePasswordVisibility")
      |> render_click()
      password_input = element(view, "#galleryPasswordInput") |> render
      
      assert password_input =~ "disabled=\"disabled\""
      assert password_input =~ "type=\"text\""
    end

    test "regenerates password on click", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")
      
      view 
      |> element("#togglePasswordVisibility")
      |> render_click()

      first_password_input = element(view, "#galleryPasswordInput") |> render

      view 
      |> element("#regeneratePasswordButton")
      |> render_click()

      second_password_input = element(view, "#galleryPasswordInput") |> render

      refute first_password_input == second_password_input
    end
  end
end
