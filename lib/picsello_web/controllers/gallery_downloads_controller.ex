defmodule PicselloWeb.GalleryDownloadsController do
  use PicselloWeb, :controller
  import Plug.Conn
  alias Picsello.Galleries.Photo

  @archive "photos.zip"
  def all(conn, _params) do
    entries =
      generate_photos()
      |> Enum.map(fn entry -> {entry.client_copy_url, entry.name} end)
      |> group()

    stream = Packmatic.build_stream(entries, on_error: :skip)

    stream
    |> Packmatic.Conn.send_chunked(conn, @archive)
  end

  defp group(entries) do
    entries
    |> Enum.group_by(&elem(&1, 1))
    |> Enum.flat_map(&dublicates(elem(&1, 1)))
    |> Enum.map(fn {url, name} -> [source: {:url, url}, path: name] end)
  end

  defp dublicates(entries) do
    case entries do
      [_ | [_ | _]] -> annotate(entries)
      _ -> entries
    end
  end

  defp annotate(entries) do
    for {{source, path}, index} <- Enum.with_index(entries) do
      path_components = Path.split(path)
      {path_components, [filename]} = Enum.split(path_components, -1)
      extname = Path.extname(filename)
      basename = Path.basename(filename, extname)
      path_components = path_components ++ ["#{basename} (#{index + 1})#{extname}"]
      {source, Path.join(path_components)}
    end
  end

  defp generate_photos() do
    photos =
      [
        # 0
        "https://image.shutterstock.com/image-illustration/number-0-600w-637209301.jpg",
        # 1
        "https://thumbs.dreamstime.com/z/number-one-gold-golden-metal-metallic-logo-icon-design-company-business-147083105.jpg",
        # 2
        "https://m.media-amazon.com/images/I/814x6GWAgEL._AC_SL1500_.jpg",
        # 3
        "https://previews.123rf.com/images/morphart/morphart1910/morphart191024607/132939046-number-3-illustration-vector-on-white-background-.jpg",
        # 4
        "https://comps.canstockphoto.com/4-kids-hand-showing-the-number-four-eps-vector_csp75005981.jpg",
        # 5
        "https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Eo_circle_blue_number-5.svg/2048px-Eo_circle_blue_number-5.svg.png",
        # 6
        "http://mobileimages.lowes.com/productimages/c1f46be3-8b04-4b54-b6a9-63a01d061f5a/11017157.jpg",
        # 7
        "https://media.istockphoto.com/photos/gold-number-7-picture-id618634822?k=20&m=618634822&s=170667a&w=0&h=CQQB_KB3K_guGFgdSAdqnFGMJL_UlxwaniZZ-L097DI=",
        # 8
        "https://images.assettype.com/freepressjournal/2021-01/dc5b0b54-e897-4fe8-9466-c9a3b2b8d1c6/etc_doc_destiny_holding_jan_7.jpg",
        # 9
        "https://comps.canstockphoto.com/grass-number-9-stock-illustrations_csp9037617.jpg",
        # 0
        "https://www.kindpng.com/picc/m/538-5389775_free-png-download-colourful-triangles-number-zero-clipart.png",
        # 1
        "https://cdn.dribbble.com/users/61921/screenshots/6420985/group_13_4x.png?compress=1&resize=400x300",
        # 2
        "https://thumbs.dreamstime.com/z/number-cute-roses-illustration-red-rose-decorated-colorful-78765242.jpg",
        # 3
        "https://us.123rf.com/450wm/inkdrop/inkdrop1903/inkdrop190301379/119198987-gold-glitter-number-3-shiny-sparkling-golden-number-3d-rendering.jpg?ver=6",
        # 4
        "https://us.123rf.com/450wm/soifer/soifer1807/soifer180700072/104245245-number-four-symbol-neon-sign-vector-number-four-template-neon-icon-light-banner-neon-signboard-night.jpg?ver=6",
        # 5
        "https://chaaicoffee.com/wp-content/uploads/2019/11/Numerology-for-Number-5-scaled.jpg",
        # 6
        "https://d2gg9evh47fn9z.cloudfront.net/800px_COLOURBOX8142174.jpg",
        # 7
        "https://us.123rf.com/450wm/asmati/asmati1807/asmati180700969/105607236-number-7-sign-design-template-element-vector-colorful-icon-with-bright-texture-of-mosaic-with-soft-s.jpg?ver=6",
        # 8
        "http://cdn5.coloringcrew.com/coloring-book/painted/201641/number-8-letters-and-numbers-numbers-102589.jpg",
        # 9
        "https://mysticalnumbers.com/wp-content/uploads/2012/07/Number-9-Mystical.png"
      ]
      |> Enum.map(fn url ->
        %Photo{
          name: generate_image_name,
          original_url: url,
          client_copy_url: url
        }
      end)
  end

  defp generate_image_name, do: :crypto.strong_rand_bytes(5) |> Base.encode16()
end
