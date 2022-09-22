defmodule PicselloWeb.GalleryDownloadsController do
  use PicselloWeb, :controller
  alias Picsello.{Orders, Photos, Galleries, Galleries.Workers.PhotoStorage, Repo}

  def download_all(conn, %{"hash" => hash, "photo_ids" => photo_ids, "is_client" => "true"}) do
    gallery = Galleries.get_gallery_by_hash!(hash)
    parse_and_download(conn, gallery, photo_ids)
  end

  def download_all(conn, %{"hash" => hash, "photo_ids" => photo_ids} = _params) do
    gallery = Galleries.get_gallery_by_hash!(hash)
    photographer = Galleries.gallery_photographer(gallery)

    if photographer.id == conn.assigns.current_user.id do
      parse_and_download(conn, gallery, photo_ids)
    else
      conn |> put_view(ErrorView) |> render("403.html")
    end
  end

  def download_all(conn, %{"hash" => hash} = _params) do
    gallery = Galleries.get_gallery_by_hash!(hash)

    %{organization: %{name: org_name}, photos: photos} = Orders.get_all_photos!(gallery)

    process_photos(conn, photos, "#{org_name}.zip")
  end

  def download_photo(%{assigns: %{current_user: %{id: id}}} = conn, %{
        "hash" => hash,
        "photo_id" => photo_id
      }) do
    gallery = Galleries.get_gallery_by_hash!(hash)
    photographer = Galleries.gallery_photographer(gallery)

    if photographer.id == id do
      photo = Photos.get!(gallery, photo_id)
      process_photo(conn, photo)
    else
      conn |> put_view(ErrorView) |> render("403.html")
    end
  end

  def download_photo(conn, %{"hash" => hash, "photo_id" => photo_id} = _params) do
    gallery = Galleries.get_gallery_by_hash!(hash)
    photo = Orders.get_purchased_photo!(gallery, photo_id)

    process_photo(conn, photo)
  end

  def download_csv(conn, %{"hash" => hash, "order_number" => order_number}) do
    %{job: %{client: client}} =
      gallery = Galleries.get_gallery_by_hash!(hash) |> Repo.preload(job: [:client])

    %{digitals: digitals, album: album} = Orders.get!(gallery, order_number)

    csv_data =
      digitals
      |> Enum.map(& &1.photo)
      |> Enum.split_with(& &1.size)
      |> assure_photo_size()
      |> Photos.csv_content()

    file_name =
      ~s(#{Date.utc_today() |> Date.to_string()}_#{client.name}_#{gallery.name}_#{album.name}.csv)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", encode_header_value(file_name))
    |> send_resp(200, csv_data)
  end

  defp parse_and_download(conn, gallery, photo_ids) do
    photo_ids = photo_ids |> String.split(",") |> Enum.map(&String.to_integer/1)
    photos = Galleries.get_photos_by_ids(gallery, photo_ids) |> some!()
    process_photos(conn, photos, "#{gallery.name}.zip")
  end

  defp assure_photo_size({with_size, []}), do: with_size

  defp assure_photo_size({with_size, without_size}) do
    without_size
    |> Task.async_stream(fn %{original_url: url, id: id} ->
      {:ok, %{status: 200, body: body}} = PhotoStorage.path_to_url(url) |> Tesla.get()
      %{id: id, size: byte_size(body)}
    end)
    |> Enum.map(&elem(&1, 1))
    |> then(&Photos.update_photos_in_bulk(without_size, &1))
    |> then(fn {:ok, photos} -> photos end)
    |> Enum.concat(with_size)
  end

  defp process_photos(conn, photos, file_name) do
    photos
    |> Picsello.Orders.Pack.stream()
    |> Packmatic.Conn.send_chunked(conn, file_name)
  end

  defp process_photo(conn, photo) do
    %HTTPoison.AsyncResponse{id: id} =
      photo.original_url |> PhotoStorage.path_to_url() |> HTTPoison.get!(%{}, stream_to: self())

    conn
    |> put_resp_header("content-disposition", encode_header_value(photo.name))
    |> send_chunked(200)
    |> process_chunks(id)
  end

  defp some!(photos),
    do:
      (case photos do
         [] -> raise Ecto.NoResultsError
         some -> some
       end)

  # Encode header value same way as Packmatic https://github.com/evadne/packmatic/blob/5fe031896dae48665d31be3d287508aa5887be24/lib/packmatic/conn.ex#L22
  defp encode_header_value(filename) do
    "attachment; filename*=UTF-8''" <> encode_filename(filename)
  end

  defp encode_filename(value) do
    URI.encode(value, fn
      x when ?0 <= x and x <= ?9 -> true
      x when ?A <= x and x <= ?Z -> true
      x when ?a <= x and x <= ?z -> true
      _ -> false
    end)
  end

  # Process chunks based on this https://stackoverflow.com/questions/43966598/how-to-read-an-http-chunked-response-and-send-chunked-response-to-client-in-elix
  defp process_chunks(conn, id) do
    receive do
      %HTTPoison.AsyncStatus{id: ^id} ->
        process_chunks(conn, id)

      %HTTPoison.AsyncHeaders{id: ^id} ->
        process_chunks(conn, id)

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk_data} ->
        chunk(conn, chunk_data)
        process_chunks(conn, id)

      %HTTPoison.AsyncEnd{id: ^id} ->
        conn
    end
  end
end
