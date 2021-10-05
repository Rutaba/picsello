defmodule PicselloWeb.GalleryLive.ClientShow do
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries.{Gallery, Photo}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"hash" => hash}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:hash, hash)
     |> assign(:images, generate_images() ++ generate_images() ++ generate_images())
    }
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"


  defp generate_images() do
    photos = 
      [
        "https://image.shutterstock.com/image-illustration/number-0-600w-637209301.jpg", # 0
        "https://thumbs.dreamstime.com/z/number-one-gold-golden-metal-metallic-logo-icon-design-company-business-147083105.jpg", # 1
        "https://m.media-amazon.com/images/I/814x6GWAgEL._AC_SL1500_.jpg", #2
        "https://previews.123rf.com/images/morphart/morphart1910/morphart191024607/132939046-number-3-illustration-vector-on-white-background-.jpg", #3
        "https://comps.canstockphoto.com/4-kids-hand-showing-the-number-four-eps-vector_csp75005981.jpg", #4
        "https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Eo_circle_blue_number-5.svg/2048px-Eo_circle_blue_number-5.svg.png", #5
        "http://mobileimages.lowes.com/productimages/c1f46be3-8b04-4b54-b6a9-63a01d061f5a/11017157.jpg", #6
        "https://media.istockphoto.com/photos/gold-number-7-picture-id618634822?k=20&m=618634822&s=170667a&w=0&h=CQQB_KB3K_guGFgdSAdqnFGMJL_UlxwaniZZ-L097DI=", #7
        "https://images.assettype.com/freepressjournal/2021-01/dc5b0b54-e897-4fe8-9466-c9a3b2b8d1c6/etc_doc_destiny_holding_jan_7.jpg", #8
        "https://comps.canstockphoto.com/grass-number-9-stock-illustrations_csp9037617.jpg", #9
  
        "https://www.kindpng.com/picc/m/538-5389775_free-png-download-colourful-triangles-number-zero-clipart.png", #0
        "https://cdn.dribbble.com/users/61921/screenshots/6420985/group_13_4x.png?compress=1&resize=400x300", #1
        "https://thumbs.dreamstime.com/z/number-cute-roses-illustration-red-rose-decorated-colorful-78765242.jpg", #2
        "https://us.123rf.com/450wm/inkdrop/inkdrop1903/inkdrop190301379/119198987-gold-glitter-number-3-shiny-sparkling-golden-number-3d-rendering.jpg?ver=6", #3
        "https://us.123rf.com/450wm/soifer/soifer1807/soifer180700072/104245245-number-four-symbol-neon-sign-vector-number-four-template-neon-icon-light-banner-neon-signboard-night.jpg?ver=6", #4
        "https://chaaicoffee.com/wp-content/uploads/2019/11/Numerology-for-Number-5-scaled.jpg", #5
        "https://d2gg9evh47fn9z.cloudfront.net/800px_COLOURBOX8142174.jpg", #6
        "https://us.123rf.com/450wm/asmati/asmati1807/asmati180700969/105607236-number-7-sign-design-template-element-vector-colorful-icon-with-bright-texture-of-mosaic-with-soft-s.jpg?ver=6", #7
        "http://cdn5.coloringcrew.com/coloring-book/painted/201641/number-8-letters-and-numbers-numbers-102589.jpg", #8
        "https://mysticalnumbers.com/wp-content/uploads/2012/07/Number-9-Mystical.png", #9
      ]
      |> Enum.map(fn url -> %Photo{name: generate_name, original_url: url} end)
    
    %Gallery{name: "MainGallery", status: "draft", photos: photos}
  end

  defp generate_name, 
    do: for _ <- 1..10, into: "", do: <<Enum.random('0123456789abcdef')>>
end
