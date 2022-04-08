defmodule PicselloWeb.GalleryLive.EditAlbumThumbnail do
  @moduledoc false
  use PicselloWeb, :live_component

  require Logger
  import PicselloWeb.LiveHelpers
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Repo, Galleries, Albums}

  @per_page 999_999

  @impl true
  def preload([assigns | _]) do
    %{gallery_id: gallery_id, album_id: album_id} = assigns

    gallery = Galleries.get_gallery!(gallery_id) |> Repo.preload(:albums)
    album = Repo.get!(Picsello.Galleries.Album, album_id) |> Repo.preload(:photo)

    [
      Map.merge(assigns, %{
        gallery: gallery,
        album: album,
        preview_url: path(album.thumbnail_url),
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
     |> assign_photos(@per_page)}
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

  def get_preview(%{preview_photo: %{preview_url: url}}), do: path(url)
  def get_preview(_), do: path(nil)
end
