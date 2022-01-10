defmodule PicselloWeb.GalleryLive.SettingsTest do
  @moduledoc false
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    conn = conn |> log_in_user(insert(:user) |> onboard!)
    %{conn: conn, gallery: insert(:gallery, %{name: "Diego Santos Weeding"})}
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
               "<button class=\"btn-primary px-11 py-3.5 cursor-pointer\" disabled=\"disabled\" phx-disable-with=\"Saving...\" type=\"submit\">Save</button><"
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
               "<button class=\"btn-primary px-11 py-3.5 cursor-pointer\" disabled=\"disabled\" phx-disable-with=\"Saving...\" type=\"submit\">Save</button><"
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

  describe "custom watermark" do
    test "opens custom watermark popup", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      view
      |> element("#openCustomWatermarkPopupButton")
      |> render_click()

      [popup_view] = live_children(view)
      assert has_element?(popup_view, "h1", "Custom watermark")
      assert has_element?(popup_view, ".watermarkTypeBtn", "Image")
      assert has_element?(popup_view, ".watermarkTypeBtn", "Text")
      assert has_element?(popup_view, "button", "Cancel")
      assert has_element?(popup_view, "button", "Save")
    end

    test "switch betwen watermark type forms", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      view
      |> element("#openCustomWatermarkPopupButton")
      |> render_click()

      [popup_view] = live_children(view)
      assert has_element?(popup_view, ".watermarkTypeBtn.active", "Image")
      assert has_element?(popup_view, ".watermarkTypeBtn", "Text")
      assert has_element?(popup_view, "#dragDrop-form")

      popup_view
      |> element(".watermarkTypeBtn", "Text")
      |> render_click()

      assert has_element?(popup_view, ".watermarkTypeBtn", "Image")
      assert has_element?(popup_view, ".watermarkTypeBtn.active", "Text")
      assert has_element?(popup_view, "#textWatermarkForm")
    end

    test "set text watermark", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      view
      |> element("#openCustomWatermarkPopupButton")
      |> render_click()

      [popup_view] = live_children(view)

      popup_view
      |> element(".watermarkTypeBtn", "Text")
      |> render_click()

      rendered =
        popup_view
        |> element("#textWatermarkForm")
        |> render_change(%{watermark: %{text: "007Agency:)"}})

      assert rendered =~
               "<input class=\"gallerySettingsInput\" id=\"textWatermarkForm_text\" name=\"watermark[text]\" placeholder=\"Enter your watermark text here\" type=\"text\" value=\"007Agency:)\"/>"

      refute has_element?(popup_view, "button.cursor-not-allowed", "Save")
    end

    test "set image watermark", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/settings")

      view
      |> element("#openCustomWatermarkPopupButton")
      |> render_click()

      [popup_view] = live_children(view)

      watermark =
        file_input(popup_view, "#dragDrop-form", :image, [
          %{
            last_modified: 1_594_171_879_000,
            name: "phoenix.png",
            content:
              File.read!(Path.join(:code.priv_dir(:picsello), "/static/images/phoenix.png")),
            size: 1_396_009,
            type: "image/png"
          }
        ])

      upload_rendered = render_upload(watermark, "phoenix.png")

      assert upload_rendered =~ "Upload complete!"
      assert upload_rendered =~ "100%"
    end
  end
end
