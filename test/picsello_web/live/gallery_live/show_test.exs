defmodule PicselloWeb.GalleryLive.ShowTest do
  @moduledoc false

  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias PicselloWeb.GalleryLive.UploadComponent

  @gallery_name "Test Gallery"

  describe "render" do
    setup :register_and_log_in_user

    setup %{user: user} do
      [
        gallery:
          insert(:gallery, job: promote_to_job(insert(:lead, user: user)), name: @gallery_name)
      ]
    end

    test "connected mount", %{conn: conn, gallery: gallery} do
      {:ok, _view, html} = live(conn, "/galleries/#{gallery.id}")
      assert html |> Floki.text() =~ @gallery_name
    end

    test "opens upload popup", %{conn: conn, gallery: gallery} do
      {:ok, view, _html} = live(conn, "/galleries/#{gallery.id}/upload")

      popup =
        assert view
               |> render_hook(:open_upload_popup, %{})
               |> Floki.text()

      assert popup =~ "Drop images or Browse"
      assert popup =~ "Supports JPEG or PNG"
    end

    test "mounts upload component", %{gallery: gallery} do
      component =
        UploadComponent
        |> render_component(%{id: UploadComponent, gallery: gallery})
        |> Floki.text()

      assert component =~ "Drop images or Browse"
      assert component =~ "Supports JPEG or PNG"
    end
  end
end
