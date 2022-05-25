defmodule PicselloWeb.GalleryDownloadsController do
  use PicselloWeb, :controller
  alias Picsello.{Orders, Galleries, Galleries.Workers.PhotoStorage}

  def download(conn, %{"hash" => hash, "order_number" => order_number} = _params) do
    %{organization: %{name: org_name}, photos: photos} =
      Orders.get_purchased_photos!(order_number, %{client_link_hash: hash})

    photos
    |> to_entries()
    |> Packmatic.build_stream()
    |> Packmatic.Conn.send_chunked(conn, "#{org_name} - #{order_number}.zip")
  end

  def download_all(conn, %{"hash" => hash} = _params) do
    gallery = Galleries.get_gallery_by_hash!(hash)

    %{organization: %{name: org_name}, photos: photos} = Orders.get_all_photos!(gallery)

    photos
    |> to_entries()
    |> Packmatic.build_stream()
    |> Packmatic.Conn.send_chunked(conn, "#{org_name}.zip")
  end

  def download_photo(conn, %{"hash" => hash, "photo_id" => photo_id} = _params) do
    gallery = Galleries.get_gallery_by_hash!(hash)
    photo = Orders.get_purchased_photo!(gallery, photo_id)

    %HTTPoison.AsyncResponse{id: id} =
      photo.original_url |> PhotoStorage.path_to_url() |> HTTPoison.get!(%{}, stream_to: self())

    conn
    |> put_resp_header("content-disposition", encode_header_value(photo.name))
    |> send_chunked(200)
    |> process_chunks(id)
  end

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

  def to_entries(photos) do
    photos
    |> Enum.map(fn entry ->
      [source: {:url, PhotoStorage.path_to_url(entry.original_url)}, path: entry.name]
    end)
    |> Enum.group_by(&Keyword.get(&1, :path))
    |> Enum.flat_map(&dublicates(elem(&1, 1)))
  end

  defp dublicates(entries) do
    case entries do
      [_ | [_ | _]] -> annotate(entries)
      _ -> entries
    end
  end

  defp annotate(entries) do
    for {[source: {:url, source}, path: path], index} <- Enum.with_index(entries) do
      path_components = Path.split(path)
      {path_components, [filename]} = Enum.split(path_components, -1)
      extname = Path.extname(filename)
      basename = Path.basename(filename, extname)
      path_components = path_components ++ ["#{basename} (#{index + 1})#{extname}"]
      [source: {:url, source}, path: Path.join(path_components)]
    end
  end
end
