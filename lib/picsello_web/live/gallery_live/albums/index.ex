defmodule PicselloWeb.GalleryLive.Albums.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_photographer"]
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Galleries, Albums}
  alias PicselloWeb.GalleryLive.Photos.Upload
  alias PicselloWeb.GalleryLive.Albums.{AlbumSettings, AlbumThumbnail}

  @blank_image "/images/album_placeholder.png"

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
            albums: albums
          }
        } = socket
      ) do
    [album | _] = Enum.filter(albums, &(&1.id == String.to_integer(id)))

    opts = [
      event: "delete_album",
      title: "Delete album?",
      subtitle:
        "Are you sure you wish to delete #{album.name}? Any photos within this album will be moved to your #{ngettext("Photos", "Unsorted photos", total(albums))}.",
      payload: %{album_id: id}
    ]

    socket
    |> make_popup(opts)
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
    |> make_popup(opts)
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
        |> put_flash(
          :gallery_success,
          "#{total(photo_ids)} unsorted #{ngettext("photo", "photos", Enum.count(photo_ids))} deleted successfully"
        )
        |> noreply()

      _ ->
        socket
        |> put_flash(:gallery_success, "Could not delete photos")
        |> close_modal()
        |> noreply()
    end
  end

  @impl true
  def handle_info({:save, _}, %{assigns: %{gallery_id: gallery_id}} = socket) do
    socket
    |> close_modal()
    |> assign(:albums, Albums.get_albums_by_gallery_id(gallery_id))
    |> put_flash(:gallery_success, "Album thumbnail successfully updated")
    |> noreply
  end

  @impl true
  def handle_info(
        {:album_settings, %{message: message}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> close_modal()
    |> push_redirect(to: Routes.gallery_albums_index_path(socket, :index, gallery.id))
    |> put_flash(:gallery_success, message)
    |> noreply()
  end

  @impl true
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
  end

  @impl true
  def handle_info({:message_composed, message_changeset}, socket) do
    add_message_and_notify(socket, message_changeset)
  end

  def thumbnail(assigns) do
    ~H"""
    <a class="mt-4 albumBlock md:w-full h-72 cursor-pointer" style={"background-image: url('#{thumbnail_url(@album)}')"} phx-click={@event} phx-value-album={@album.id}>
      <div class="flex flex-row items-end justify-start h-full gap-2">
        <span class="font-sans font-bold text-white text-1xl"><%= @album.name %></span>
      </div>
    </a>
    """
  end

  defp thumbnail_url(%{thumbnail_photo: nil}), do: @blank_image
  defp thumbnail_url(%{thumbnail_photo: photo}), do: preview_url(photo)
end
