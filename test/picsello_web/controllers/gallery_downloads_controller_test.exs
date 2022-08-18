defmodule PicselloWeb.GalleryDownloadsControllerTest do
  use PicselloWeb.ConnCase, async: true
  import Money.Sigils

  def add_photos(order, photos) do
    for(photo <- photos, reduce: order) do
      order ->
        insert(:digital, order: order, photo: photo)
        order
    end
  end

  @doc """
    taken from [packmatic tests](https://github.com/evadne/packmatic/blob/deec90a8fdd33e252d124328196129a19fc070bb/test/packmatic/packmatic_test.exs#L177)
  """
  def get_zip_files(target) do
    {:ok, zip_handle} = :zip.zip_open(target)
    {:ok, zip_list} = :zip.zip_list_dir(zip_handle)
    :ok = :zip.zip_close(zip_handle)

    for {:zip_file, name, _, _, _, _} <- zip_list do
      to_string(name)
    end
  end

  setup do
    [original_url: image_url()]
  end

  setup %{original_url: original_url} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, fn ^original_url ->
      original_url
    end)

    :ok
  end

  def insert_gallery(opts \\ []) do
    {charge_for_downloads, opts} = Keyword.pop(opts, :charge_for_downloads, true)
    download_each_price = if charge_for_downloads, do: ~M[1]USD, else: ~M[0]USD

    org_attrs =
      case Keyword.get(opts, :organization_name) do
        nil -> %{}
        name -> %{name: name}
      end

    organization = insert(:organization, org_attrs)

    insert(:gallery,
      job:
        insert(:lead,
          client: insert(:client, organization: organization),
          package:
            insert(:package, organization: organization, download_each_price: download_each_price)
        )
    )
  end

  describe "Get /galleries/:gallery_id/photos/:photo_id/download" do
    def get_photo(conn, gallery, photo_id) do
      get(
        conn,
        Routes.gallery_downloads_path(
          conn,
          :download_photo,
          gallery.client_link_hash,
          photo_id
        )
      )
    end

    test "sends a file when bundle is purchased", %{
      conn: conn,
      original_url: original_url
    } do
      gallery = insert_gallery(organization_name: "org name")

      insert(:order, gallery: gallery, placed_at: DateTime.utc_now(), bundle_price: ~M[5000]USD)

      [first_photo | _] =
        insert_list(3, :photo,
          gallery: gallery,
          original_url: original_url,
          name: "original name.jpg"
        )

      conn = get_photo(conn, gallery, first_photo.id)

      assert %{"content-disposition" => "attachment; filename*=UTF-8''" <> download_filename} =
               Enum.into(conn.resp_headers, %{})

      assert "original name.jpg" == URI.decode(download_filename)
    end

    test "sends a file when package does not charge for downloads", %{
      conn: conn,
      original_url: original_url
    } do
      gallery = insert_gallery(organization_name: "org name", charge_for_downloads: false)

      [first_photo | _] =
        insert_list(3, :photo,
          gallery: gallery,
          original_url: original_url,
          name: "original name.jpg"
        )

      conn = get_photo(conn, gallery, first_photo.id)

      assert %{"content-disposition" => "attachment; filename*=UTF-8''" <> download_filename} =
               Enum.into(conn.resp_headers, %{})

      assert "original name.jpg" == URI.decode(download_filename)
    end

    test "photo is in gallery's placed order", %{conn: conn, original_url: original_url} do
      gallery = insert_gallery(organization_name: "org name")

      photo =
        insert(:photo,
          gallery: gallery,
          original_url: original_url,
          name: "original name.jpg"
        )

      add_photos(insert(:order, gallery: gallery, placed_at: DateTime.utc_now()), [photo])

      conn = get_photo(conn, gallery, photo.id)

      assert %{"content-disposition" => "attachment; filename*=UTF-8''" <> download_filename} =
               Enum.into(conn.resp_headers, %{})

      assert "original name.jpg" == URI.decode(download_filename)
    end

    test "photo is in gallery's order that is not paid for", %{
      conn: conn,
      original_url: original_url
    } do
      gallery = insert_gallery()

      photo =
        insert(:photo,
          gallery: gallery,
          original_url: original_url
        )

      order = insert(:order, gallery: gallery, placed_at: DateTime.utc_now())
      insert(:intent, order: order)
      refute Picsello.Orders.client_paid?(order)
      add_photos(order, [photo])

      assert_raise(Ecto.NoResultsError, fn ->
        get_photo(conn, gallery, photo.id)
      end)
    end

    test "no such photo in any gallery's order", %{conn: conn, original_url: original_url} do
      gallery = insert_gallery()

      [photo1, photo2] =
        insert_list(2, :photo,
          gallery: gallery,
          original_url: original_url
        )

      add_photos(insert(:order, gallery: gallery, placed_at: DateTime.utc_now()), [photo1])

      assert_raise(Ecto.NoResultsError, fn ->
        get_photo(conn, gallery, photo2.id)
      end)
    end
  end
end
