defmodule PicselloWeb.GalleryLive.PhotographerIndexTest do
  @moduledoc false
  use PicselloWeb.ConnCase, async: true
  import Money.Sigils
  import Phoenix.LiveViewTest
  alias Picsello.{Repo, Package, Galleries.GalleryDigitalPricing}

  setup %{conn: conn} do
    user = insert(:user)
    conn = conn |> log_in_user(user |> onboard!)

    Picsello.PhotoStorageMock
    |> Mox.stub(:path_to_url, & &1)
    |> Mox.stub(:params_for_upload, fn _ -> [] end)

    package = insert(:package, download_each_price: ~M[2500]USD)
    job = insert(:lead, type: "wedding", user: user, package: package) |> promote_to_job()
    gallery = insert(:gallery, %{name: "Ukasha Habib Wedding", job: job})
    insert(:gallery_digital_pricing, %{gallery: gallery, download_each_price: ~M[10]USD})

    %{
      conn: conn,
      gallery: gallery
    }
  end

  describe "general render" do
    test "connected mount", %{conn: conn, gallery: gallery} do
      {:ok, _view, html} = live(conn, "/galleries/#{gallery.id}")
      assert html |> Floki.text() =~ "Cover photo"
      assert html |> Floki.text() =~ "Gallery name"
      assert html |> Floki.text() =~ "Gallery password"
      assert html |> Floki.text() =~ "Expiration date"
      assert html |> Floki.text() =~ "Watermark"
      assert html |> Floki.text() =~ "Delete gallery"
    end

    test "custom watermark is not present when package does not charge for downloads", %{
      conn: conn,
      gallery: gallery
    } do
      Repo.update_all(Package, set: [download_each_price: ~M[0]USD])
      Repo.update_all(GalleryDigitalPricing, set: [download_each_price: ~M[0]USD])
      {:ok, _view, html} = live(conn, "/galleries/#{gallery.id}")
      refute html |> Floki.text() =~ "Watermark"
    end
  end

  describe "gallery name update" do
    def render_update_name(attrs) do
      gallery = insert(:gallery, attrs)
      insert(:gallery_digital_pricing, gallery: gallery)

      render_component(PicselloWeb.GalleryLive.Settings.UpdateNameComponent,
        id: :test,
        gallery: gallery
      )
    end

    test "update with valid input", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      updated_render =
        view
        |> element("#updateGalleryNameForm")
        |> render_change(%{
          gallery: %{name: "Client gallery"}
        })

      assert String.contains?(updated_render, "value=\"Client gallery\"")

      assert "Save" ==
               updated_render
               |> Floki.parse_fragment!()
               |> Floki.find("#updateGalleryNameForm button[type=submit]:not(:disabled)")
               |> Floki.text()
    end

    test "update disabled with empty value", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      updated_render =
        view
        |> element("#updateGalleryNameForm")
        |> render_change(%{
          gallery: %{name: ""}
        })

      assert "Save" ==
               updated_render
               |> Floki.parse_fragment!()
               |> Floki.find("#updateGalleryNameForm button[type=submit]:disabled")
               |> Floki.text()
    end

    test "update disabled with too long value", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      updated_render =
        view
        |> element("#updateGalleryNameForm")
        |> render_change(%{
          gallery: %{name: "TestTestTestTestTestTestTestTestTestTestTestTestTestTest"}
        })

      assert "Save" ==
               updated_render
               |> Floki.parse_fragment!()
               |> Floki.find("#updateGalleryNameForm button[type=submit]:disabled")
               |> Floki.text()
    end

    test "reset gallery name", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      updated_render =
        view
        |> element("button", "Reset")
        |> render_click()

      String.contains?(updated_render, gallery.name)
    end
  end

  describe "manage password" do
    test "render password input", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")
      password_input = element(view, "#galleryPasswordInput") |> render

      assert password_input =~ "disabled=\"disabled\""
      assert password_input =~ "type=\"password\""
    end

    test "shows password when on click", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      view
      |> element("#togglePasswordVisibility")
      |> render_click()

      password_input = element(view, "#galleryPasswordInput") |> render

      assert password_input =~ "disabled=\"disabled\""
      assert password_input =~ "type=\"text\""
    end

    test "regenerates password on click", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

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
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      view
      |> element("#watermark_popup")
      |> render_click()

      [popup_view | _] = live_children(view)
      assert has_element?(popup_view, "h1", "Custom watermark")
      assert has_element?(popup_view, ".watermarkTypeBtn", "Image")
      assert has_element?(popup_view, ".watermarkTypeBtn", "Text")
      assert has_element?(popup_view, "button", "Cancel")
      assert has_element?(popup_view, "button", "Save")
    end

    test "switch betwen watermark type forms", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      view
      |> element("#watermark_popup")
      |> render_click()

      [popup_view | _] = live_children(view)
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
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      view
      |> element("#watermark_popup")
      |> render_click()

      [popup_view | _] = live_children(view)

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
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}")

      view
      |> element("#watermark_popup")
      |> render_click()

      [popup_view | _] = live_children(view)

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
