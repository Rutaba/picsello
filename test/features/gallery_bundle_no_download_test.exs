defmodule Picsello.GalleryBundleNoDownloadTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
  import Mox
  use Oban.Testing, repo: Picsello.Repo

  alias Picsello.Repo

  setup :verify_on_exit!

  def gcs_resp(status),
    do:
      &(&1
        |> Plug.Conn.put_resp_header("Access-Control-Allow-Origin", "*")
        |> Plug.Conn.resp(status, ""))

  setup do
    %{port: port} = bypass = Bypass.open()
    bypass_url = PicselloWeb.Endpoint.struct_url() |> Map.put(:port, port) |> URI.to_string()

    bypass
    |> Bypass.stub("OPTIONS", "/", gcs_resp(200))

    bypass
    |> Bypass.stub("POST", "/", gcs_resp(204))

    Picsello.PhotoStorageMock
    |> stub(:get, fn _ -> {:ok, %{name: "gallery.zip"}} end)
    |> stub(:path_to_url, fn _path -> image_url() end)
    |> stub(:params_for_upload, fn _ -> %{url: bypass_url, fields: %{key: "image.png"}} end)
    |> stub(:delete, fn _ -> :ok end)
    |> stub(:initiate_resumable, fn _, _ ->
      {:ok, %Tesla.Env{status: 200} |> Tesla.put_header("location", "https://example.com")}
    end)
    |> stub(:continue_resumable, fn _, _, _ ->
      {:ok, %Tesla.Env{status: 200}}
    end)

    :ok
  end

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery, user: user} do
    insert(:gallery_digital_pricing, %{
      gallery: gallery,
      download_count: 0,
      print_credits: Money.new(0)
    })

    insert(:gallery_client, %{email: user.email, gallery_id: gallery.id})
    insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})

    [gallery: gallery]
  end

  test "checks if gallery doesn't have download button", %{
    session: session,
    gallery: gallery
  } do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_text(gallery.name)
    |> click(css("a", text: "View Gallery"))
    |> refute_has(link("Download purchased photos"))
  end

  test "album doesn't have downloads button", %{
    session: session,
    gallery: gallery
  } do
    album = insert(:album, %{gallery_id: gallery.id}) |> Repo.preload([:photos, :thumbnail_photo])

    session
    |> visit("/galleries/#{gallery.id}/albums")
    |> assert_text(gallery.name)
    |> click(css("#actions-#{album.id}"))
    |> click(css("*[phx-click='go_to_album']", text: "Go to album"))
    |> attach_file(file_field("Add photos", visible: false),
      path: "assets/static/images/phoenix.png"
    )
    |> assert_has(css(".muuri-item"))

    session
    |> visit("/gallery/#{gallery.client_link_hash}/album/#{album.id}")
    |> refute_has(link("Download purchased album photos"))
  end
end
