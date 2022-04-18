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
    [
      original_url:
        PicselloWeb.Endpoint.struct_url()
        |> Map.put(:path, PicselloWeb.Endpoint.static_path("/images/phoenix.png"))
        |> URI.to_string()
    ]
  end

  setup %{original_url: original_url} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, fn path ->
      assert path == original_url
      path
    end)

    :ok
  end

  describe "Get /galleries/:gallery_id/order/:order_id/zip" do
    def get_zip(conn, gallery, order) do
      get(
        conn,
        Routes.gallery_downloads_path(
          conn,
          :download,
          gallery.client_link_hash,
          Picsello.Cart.OrderNumber.to_number(order.id)
        )
      )
    end

    test "no such gallery", %{conn: conn} do
      order = add_photos(insert(:order), [insert(:photo)])

      assert_raise(Ecto.NoResultsError, fn ->
        get_zip(conn, %{client_link_hash: "abc"}, order)
      end)
    end

    test "no such order in gallery", %{conn: conn} do
      gallery = insert(:gallery)
      order = add_photos(insert(:order, gallery: gallery), [insert(:photo, gallery: gallery)])

      assert_raise(Ecto.NoResultsError, fn ->
        get_zip(conn, gallery, %{id: order.id + 1})
      end)
    end

    test "order has no digitals", %{conn: conn} do
      gallery = insert(:gallery)
      order = insert(:order, gallery: gallery)

      assert_raise(Ecto.NoResultsError, fn ->
        get_zip(conn, gallery, order)
      end)
    end

    test "sends a zip of all purchased originals in order", %{
      conn: conn,
      original_url: original_url
    } do
      gallery =
        insert(:gallery,
          job:
            insert(:lead,
              client: insert(:client, organization: insert(:organization, name: "org name"))
            )
        )

      order = insert(:order, gallery: gallery, placed_at: DateTime.utc_now())

      [_skipped | ordered_photos] =
        insert_list(3, :photo,
          gallery: gallery,
          original_url: original_url,
          name: "original name.jpg"
        )

      order = add_photos(order, ordered_photos)

      conn = get_zip(conn, gallery, order)

      assert %{"content-disposition" => "attachment; filename*=UTF-8''" <> download_filename} =
               Enum.into(conn.resp_headers, %{})

      assert "org name - #{Picsello.Cart.OrderNumber.to_number(order.id)}.zip" ==
               URI.decode(download_filename)

      assert ["original name (1).jpg", "original name (2).jpg"] =
               conn.resp_body |> get_zip_files() |> Enum.sort()
    end

    test "sends a zip of all photos when bundle is purchased", %{
      conn: conn,
      original_url: original_url
    } do
      gallery =
        insert(:gallery,
          job:
            insert(:lead,
              client: insert(:client, organization: insert(:organization, name: "org name"))
            )
        )

      order =
        insert(:order, gallery: gallery, placed_at: DateTime.utc_now(), bundle_price: ~M[5000]USD)

      insert_list(3, :photo,
        gallery: gallery,
        original_url: original_url,
        name: "original name.jpg"
      )

      conn = get_zip(conn, gallery, order)

      assert %{"content-disposition" => "attachment; filename*=UTF-8''" <> download_filename} =
               Enum.into(conn.resp_headers, %{})

      assert "org name - #{Picsello.Cart.OrderNumber.to_number(order.id)}.zip" ==
               URI.decode(download_filename)

      assert ["original name (1).jpg", "original name (2).jpg", "original name (3).jpg"] =
               conn.resp_body |> get_zip_files() |> Enum.sort()
    end
  end

  describe "Get /galleries/:gallery_id/zip" do
    def get_zip(conn, gallery) do
      get(
        conn,
        Routes.gallery_downloads_path(
          conn,
          :download_all,
          gallery.client_link_hash
        )
      )
    end

    test "sends a zip of all photos when bundle is purchased", %{
      conn: conn,
      original_url: original_url
    } do
      gallery =
        insert(:gallery,
          job:
            insert(:lead,
              client: insert(:client, organization: insert(:organization, name: "org name"))
            )
        )

      insert(:order, gallery: gallery, placed_at: DateTime.utc_now(), bundle_price: ~M[5000]USD)

      insert_list(3, :photo,
        gallery: gallery,
        original_url: original_url,
        name: "original name.jpg"
      )

      conn = get_zip(conn, gallery)

      assert %{"content-disposition" => "attachment; filename*=UTF-8''" <> download_filename} =
               Enum.into(conn.resp_headers, %{})

      assert "org name.zip" == URI.decode(download_filename)

      assert ["original name (1).jpg", "original name (2).jpg", "original name (3).jpg"] =
               conn.resp_body |> get_zip_files() |> Enum.sort()
    end

    test "sends a zip of all photos when package does not charge for downloads", %{
      conn: conn,
      original_url: original_url
    } do
      organization = insert(:organization, name: "org name")
      package = insert(:package, organization: organization, download_each_price: ~M[0]USD)

      gallery =
        insert(:gallery,
          job:
            insert(:lead,
              client: insert(:client, organization: organization),
              package: package
            )
        )

      insert_list(3, :photo,
        gallery: gallery,
        original_url: original_url,
        name: "original name.jpg"
      )

      conn = get_zip(conn, gallery)

      assert %{"content-disposition" => "attachment; filename*=UTF-8''" <> download_filename} =
               Enum.into(conn.resp_headers, %{})

      assert "org name.zip" == URI.decode(download_filename)

      assert ["original name (1).jpg", "original name (2).jpg", "original name (3).jpg"] =
               conn.resp_body |> get_zip_files() |> Enum.sort()
    end
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
      gallery =
        insert(:gallery,
          job:
            insert(:lead,
              client: insert(:client, organization: insert(:organization, name: "org name"))
            )
        )

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
      organization = insert(:organization, name: "org name")
      package = insert(:package, organization: organization, download_each_price: ~M[0]USD)

      gallery =
        insert(:gallery,
          job:
            insert(:lead,
              client: insert(:client, organization: organization),
              package: package
            )
        )

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

    test "photo is in gallery's order is placed", %{conn: conn, original_url: original_url} do
      gallery = insert(:gallery)

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

    test "photo is in gallery's order that is not placed", %{
      conn: conn,
      original_url: original_url
    } do
      gallery = insert(:gallery)

      photo =
        insert(:photo,
          gallery: gallery,
          original_url: original_url
        )

      add_photos(insert(:order, gallery: gallery), [photo])

      assert_raise(Ecto.NoResultsError, fn ->
        get_photo(conn, gallery, photo.id)
      end)
    end

    test "no such photo in any gallery's order", %{conn: conn, original_url: original_url} do
      gallery = insert(:gallery)

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
