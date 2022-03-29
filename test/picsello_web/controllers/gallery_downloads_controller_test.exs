defmodule PicselloWeb.GalleryDownloadsControllerTest do
  use PicselloWeb.ConnCase, async: true

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
  end
end
