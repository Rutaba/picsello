defmodule PicselloWeb.GalleryLive.Albums.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Galleries, Albums}
  alias PicselloWeb.GalleryLive.Photos.Upload
  alias PicselloWeb.GalleryLive.Albums.{AlbumSettings, AlbumThumbnail}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:total_progress, 0)
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => gallery_id}, _uri, socket) do
    gallery = Galleries.get_gallery!(gallery_id)

    socket
    |> assign(:gallery_id, gallery_id)
    |> assign(:albums, Albums.get_albums_by_gallery_id(gallery_id))
    |> assign(:gallery, gallery)
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_unsorted_photos",
        _,
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery_id))
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_album",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery_id, album_id))
    |> noreply()
  end

  @impl true
  def handle_event(
        "album_settings_popup",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    album = Albums.get_album!(album_id)

    socket
    |> open_modal(AlbumSettings, %{
      gallery_id: gallery_id,
      album: album
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "add_album_popup",
        %{},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> open_modal(AlbumSettings, %{gallery_id: gallery_id})
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit_album_thumbnail_popup",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> open_modal(AlbumThumbnail, %{album_id: album_id, gallery_id: gallery_id})
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete_album_popup",
        %{"id" => id},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    opts = [
      event: "delete_album",
      title: "Delete this album?",
      subtitle: "Are you sure you wish to permanently delete this album from #{gallery.name} ?",
      payload: %{album_id: id}
    ]

    socket
    |> make_delete_popup(opts)
  end

  @impl true
  def handle_event(
        "delete_all_unsorted_photos",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    opts = [
      event: "delete_unsorted_photos",
      title: "Delete this album?",
      subtitle: "Are you sure you wish to permanently delete this album from #{gallery.name} ?"
    ]

    socket
    |> make_delete_popup(opts)
  end

  @impl true
  def handle_event("client-link", _, socket) do
    share_gallery(socket)
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_album", %{album_id: album_id}},
        %{assigns: %{gallery_id: gallery_id}} = socket
      ) do
    album = Albums.get_album!(album_id)

    case Galleries.delete_album(album) do
      {:ok, _album} ->
        albums = Albums.get_albums_by_gallery_id(gallery_id)

        if Enum.empty?(albums) do
          socket
          |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery_id))
        else
          socket
          |> push_redirect(to: Routes.gallery_albums_index_path(socket, :index, gallery_id))
        end
        |> close_modal()
        |> put_flash(:gallery_success, "Album deleted successfully")
        |> noreply()

      _any ->
        socket
        |> close_modal()
        |> put_flash(:gallery_success, "Could not delete album")
        |> noreply()
    end
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_unsorted_photos", %{}},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    photo_ids =
      Galleries.get_all_unsorted_photos(gallery.id)
      |> Enum.map(& &1.id)

    case Galleries.delete_photos(photo_ids) do
      {:ok, _} ->
        socket
        |> close_modal()
        |> put_flash(:gallery_success, "#{total(photo_ids)} unsorted #{ngettext("photo", "photos", Enum.count(photo_ids))} deleted successfully")
        |> noreply()

      _ ->
        socket
        |> put_flash(:gallery_success, "Could not delete photos")
        |> close_modal()
        |> noreply()
    end
  end

  @impl true
  def handle_info({:save, %{title: title}}, %{assigns: %{gallery_id: gallery_id}} = socket) do
    socket
    |> close_modal()
    |> assign(:albums, Albums.get_albums_by_gallery_id(gallery_id))
    |> put_flash(:gallery_success, "#{title} successfully updated")
    |> noreply
  end

  @impl true
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
  end

  @impl true
  def handle_info({:message_composed, message_changeset}, socket) do
    add_message_and_notify(socket, message_changeset)
  end
end
