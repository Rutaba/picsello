defmodule PicselloWeb.GalleryLive.EditAlbumThumbnail do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  import PicselloWeb.LiveHelpers

  alias Phoenix.PubSub
  alias Picsello.Galleries
  alias Picsello.Galleries.Album
  alias Picsello.Repo

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:selected_all, "false")
      |> assign(:selected_photos, nil)
    }
  end

  @impl true
  def handle_params(%{"id" => id, "album_id" => album_id}, _, socket) do
    gallery = Galleries.get_gallery!(id) |> Repo.preload(:albums)

    album = Repo.get!(Picsello.Galleries.Album, album_id) |> Repo.preload(:photo)

    photos = Galleries.get_all_album_photos(id, album_id)

    photo_ids = Enum.map(photos, fn photo -> photo.id end)

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery.id}")
    end

    socket
    |> assign(
      gallery: gallery,
      album: album,
      photos: photos,
      photo_ids: photo_ids,
      thumbnail_url: album.thumbnail_url
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "close_thumbnail",
        _,
        socket
      ) do
    socket
    |> push_redirect(
      to:
        Routes.gallery_albums_path(socket, :albums, socket.assigns.gallery.id,
          upload_toast: "hidden",
          upload_toast_text: nil
        )
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "save_thumbnail",
        _,
        %{
          assigns: %{
            album: album,
            thumbnail_url: thumbnail_url
          }
        } = socket
      ) do
    album
    |> Album.update_changeset(%{thumbnail_url: thumbnail_url})
    |> Repo.update()

    socket
    |> push_redirect(
      to:
        Routes.gallery_albums_path(socket, :albums, socket.assigns.gallery.id,
          upload_toast: nil,
          upload_toast_text: "Album thumbnail successfully updated"
        )
    )
    |> noreply()
  end

  def handle_info(
        {:selected_photos, id},
        socket
      ) do
    photo = Galleries.get_photo(id)

    socket
    |> assign(:selected_photos, id)
    |> assign(:thumbnail_url, photo.preview_url)
    |> noreply()
  end
end
