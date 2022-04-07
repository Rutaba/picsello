defmodule PicselloWeb.GalleryLive.EditAlbumThumbnail do
  @moduledoc false
  use PicselloWeb, :live_component

  require Logger
  import PicselloWeb.LiveHelpers

  alias Picsello.{Repo, Galleries, Albums}

  @per_page 24

  @impl true
  def preload([assigns | _]) do
    %{gallery_id: gallery_id, album_id: album_id} = assigns

    gallery = Galleries.get_gallery!(gallery_id) |> Repo.preload(:albums)

    album = Repo.get!(Picsello.Galleries.Album, album_id) |> Repo.preload(:photo)

    photos = Galleries.get_all_album_photos(gallery_id, album_id)

    [
      Map.merge(assigns, %{
        gallery: gallery,
        album: album,
        preview_url: path(album.thumbnail_url),
        photos: photos,
        page_title: "Album thumbnail",
        thumbnail_url: album.thumbnail_url,
        favorites_count: Galleries.gallery_favorites_count(gallery),
        title: album.name
      })
    ]
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:selected, false)
     |> assign(
       :description,
       "Select one of the photos in your album to use as your album thumbnail. Your client will see this on their main gallery page."
     )
     |> assign(:page, 0)
     |> assign(:favorites_filter, false)
     |> assign_photos()}
  end

  def handle_event(
        "click",
        %{"preview" => preview},
        socket
      ) do
    socket
    |> assign(:selected, true)
    |> assign(:preview_url, path(preview))
    |> assign(:thumbnail_url, preview)
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

    send(
      self(),
      {:save, %{preview_url: preview_url, title: album.name}}
    )

    socket
    |> noreply()
  end

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{id: id},
             page: page,
             favorites_filter: filter
           }
         } = socket,
         per_page \\ @per_page
       ) do
    opts = [only_favorites: filter, offset: per_page * page]
    photos = Galleries.get_gallery_photos(id, per_page + 1, page, opts)

    socket
    |> assign(:photos, photos |> Enum.take(per_page))
    |> assign(:has_more_photos, photos |> length > per_page)
  end

  def get_preview(%{preview_photo: %{preview_url: url}}), do: path(url)
  def get_preview(_), do: path(nil)
end
