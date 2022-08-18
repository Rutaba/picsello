defmodule Picsello.GalleryBundleDownloadTest do
  use Picsello.FeatureCase, async: true
  import Mox

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

  setup %{sessions: [photographer_session, client_session]} do
    %{session: client_session, gallery: gallery} =
      %{session: client_session} |> authenticated_gallery_client() |> Enum.into(%{})

    photographer =
      gallery
      |> Ecto.assoc(:organization)
      |> Picsello.Repo.one()
      |> Picsello.Repo.preload(:user)
      |> Map.get(:user)
      |> Map.put(:onboarding, nil)
      |> onboard!()

    %{session: photographer_session} =
      %{session: photographer_session, user: photographer} |> authenticated() |> Enum.into(%{})

    [
      sessions: [photographer_session, client_session],
      gallery: gallery,
      photographer: photographer
    ]
  end

  @sessions 2
  test "resets client link when photographer updates gallery", %{
    sessions: [photographer_session, client_session],
    gallery: gallery
  } do
    client_session
    |> assert_text(gallery.name)
    |> click(link("View Gallery"))
    |> assert_has(link("Download all"))

    photographer_session
    |> visit(Routes.gallery_photos_index_path(PicselloWeb.Endpoint, :index, gallery.id))
    |> assert_text(gallery.name)
    |> attach_file(file_field("Add photos", visible: false),
      path: "assets/static/images/phoenix.png"
    )
    |> assert_has(css(".muuri-item"))

    assert [
             %{worker: "Picsello.Workers.PackDigitals", state: "scheduled"},
             %{worker: "Picsello.Workers.PackGallery", state: "completed"}
           ] = run_jobs()

    client_session
    |> assert_text("Preparing Download")

    assert [
             %{worker: "Picsello.Workers.PackGallery", state: "completed"},
             %{worker: "Picsello.Workers.PackDigitals", state: "completed"}
           ] = run_jobs(with_scheduled: true)

    assert_receive({:delivered_email, %{subject: "Download Ready"}})

    client_session
    |> assert_has(link("Download all"))

    photographer_session
    |> click(css("div[id$='-remove']", visible: false))
    |> click(button("Yes, delete"))
    |> assert_text("nothing here")

    assert [
             %{worker: "Picsello.Workers.PackDigitals", state: "scheduled"},
             %{worker: "Picsello.Workers.PackGallery", state: "completed"}
           ] = run_jobs() |> Enum.drop(2)

    client_session
    |> assert_text("Preparing Download")

    assert [
             %{worker: "Picsello.Workers.PackGallery", state: "completed"},
             %{worker: "Picsello.Workers.PackDigitals", state: "completed"}
           ] = run_jobs(with_scheduled: true) |> Enum.drop(2)
  end
end
