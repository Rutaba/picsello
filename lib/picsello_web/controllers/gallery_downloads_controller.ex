defmodule PicselloWeb.GalleryDownloadsController do
  use PicselloWeb, :controller
  import Plug.Conn
  alias Picsello.Galleries

  def download(conn, %{"hash" => hash, "type" => type} = _params) do
    try do
      gallery = Galleries.get_gallery_by_hash(hash)
      photos = Galleries.load_gallery_photos(gallery, type)

      photos
      |> group()
      |> Packmatic.build_stream(on_error: :skip)
      |> Packmatic.Conn.send_chunked(conn, "#{gallery.name}.zip")
    rescue
      e -> conn |> send_resp(500, "#{e}")
    end
  end

  def group(entries) do
    entries
    |> Enum.map(fn entry -> [source: {:url, entry.original_url}, path: entry.name] end)
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
