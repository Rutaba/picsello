defmodule PicselloWeb.GalleryDownloadsController do
  use PicselloWeb, :controller
  alias Picsello.{Cart, Galleries, Galleries.Workers.PhotoStorage}

  def download(conn, %{"hash" => hash, "order_number" => order_number} = _params) do
    %{organization: %{name: org_name}, photos: photos} =
      Cart.get_purchased_photos!(order_number, %{client_link_hash: hash})

    photos
    |> to_entries()
    |> Packmatic.build_stream()
    |> Packmatic.Conn.send_chunked(conn, "#{org_name} - #{order_number}.zip")
  end

  def download_all(conn, %{"hash" => hash} = _params) do
    gallery = Galleries.get_gallery_by_hash!(hash)

    %{organization: %{name: org_name}, photos: photos} = Cart.get_all_photos!(gallery)

    photos
    |> to_entries()
    |> Packmatic.build_stream()
    |> Packmatic.Conn.send_chunked(conn, "#{org_name}.zip")
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
