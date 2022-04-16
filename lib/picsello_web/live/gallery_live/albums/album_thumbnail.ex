defmodule PicselloWeb.GalleryLive.Albums.AlbumThumbnail do
  @moduledoc false
  use PicselloWeb, :live_component

  require Logger
  import PicselloWeb.LiveHelpers
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Repo, Galleries, Albums}

  @per_page 999_999
  @coordi [0, 0, 1120, 0, 0, 1100, 1120, 1100]

  @impl true
  def preload([assigns | _]) do
    %{gallery_id: gallery_id, album_id: album_id} = assigns

    gallery = Galleries.get_gallery!(gallery_id) |> Repo.preload(:albums)
    album = Albums.get_album!(album_id) |> Repo.preload(:photos)

    [
      Map.merge(assigns, %{
        gallery: gallery,
        album: album,
        preview_url: path(album.thumbnail_url),
        page_title: "Album thumbnail",
        thumbnail_url: album.thumbnail_url,
        favorites_count: Galleries.gallery_favorites_count(gallery),
        title: album.name,
        frame_id: 2
      })
    ]
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> then(fn socket ->
      push_event(socket, "set_preview", %{
        preview: assigns[:preview_url],
        frame: "card_blank.png",
        coords: @coordi,
        target: "#{assigns[:frame_id]}-edit"
      })
    end)
    |> assign(:selected, false)
    |> assign(
      :description,
      "Select one of the photos in your album to use as your album thumbnail. Your client will see this on their main gallery page."
    )
    |> assign(:page, 0)
    |> assign(:favorites_filter, false)
    |> assign_photos(@per_page)
    |> ok()
  end

  def handle_event(
        "click",
        %{"preview" => preview},
        %{assigns: %{frame_id: frame_id}} = socket
      ) do
    socket
    |> assign(:selected, true)
    |> assign(:preview_url, path(preview))
    |> assign(:thumbnail_url, preview)
    |> push_event("set_preview", %{
      preview: path(preview),
      frame: "card_blank.png",
      coords: @coordi,
      target: "#{frame_id}-edit"
    })
    |> noreply
  end

  @impl true
  def handle_event(
        "save",
        _,
        %{assigns: %{preview_url: preview_url, album: album, thumbnail_url: thumbnail_url}} =
          socket
      ) do
    {:ok, album} = album |> Albums.update_album(%{thumbnail_url: thumbnail_url})

    send(self(), {:save, %{preview_url: preview_url, title: album.name}})

    socket
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white h-screen w-screen overflow-auto">
      <.preview assigns={assigns}>
        <div id={"preview-#{@frame_id}"} class="flex justify-center items-start row-span-2 previewImg" phx-hook="Preview">
          <canvas id={"canvas-#{@frame_id}-edit"} width="300" height="255" class="edit bg-gray-300"></canvas>
        </div>
      </.preview>
    </div>
    """
  end
end
