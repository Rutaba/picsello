defmodule PicselloWeb.GalleryLive.Albums.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_photographer"]
  import PicselloWeb.GalleryLive.Shared
  import PicselloWeb.Live.Shared, only: [make_popup: 2]
  import PicselloWeb.Shared.StickyUpload, only: [sticky_upload: 1]

  alias Picsello.{Repo, Galleries, Albums}
  alias PicselloWeb.GalleryLive.Albums.{AlbumSettings, AlbumThumbnail}

  @blank_image "/images/album_placeholder.png"

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:total_progress, 0)
    |> assign(:photos_error_count, 0)
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => gallery_id} = params, _uri, socket) do
    gallery = Galleries.get_gallery!(gallery_id) |> Repo.preload(:photographer)

    albums =
      case client_liked_album(gallery.id) do
        nil -> Albums.get_albums_by_gallery_id(gallery.id) |> Repo.preload(:orders)
        album -> (Albums.get_albums_by_gallery_id(gallery.id) |> Repo.preload(:orders)) ++ [album]
      end

    socket
    |> assign(:gallery_id, gallery_id)
    |> assign(:albums, albums)
    |> assign(:gallery, gallery)
    |> is_mobile(params)
    |> noreply()
  end

  @impl true
  def handle_event("back_to_navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket |> assign(:is_mobile, !is_mobile) |> noreply
  end

  @impl true
  def handle_event(
        "go_to_unsorted_photos",
        _,
        %{
          assigns: %{
            gallery_id: gallery_id,
            is_mobile: is_mobile
          }
        } = socket
      ) do
    is_mobile = if(is_mobile, do: [], else: [is_mobile: false])

    socket
    |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery_id, is_mobile))
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_album",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery_id: gallery_id,
            is_mobile: is_mobile
          }
        } = socket
      ) do
    is_mobile = if(is_mobile, do: [], else: [is_mobile: false])

    socket
    |> push_redirect(
      to: Routes.gallery_photos_index_path(socket, :index, gallery_id, album_id, is_mobile)
    )
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
    album = Albums.get_album!(album_id) |> Repo.preload(:orders)

    socket
    |> open_modal(AlbumSettings, %{
      gallery_id: gallery_id,
      album: album,
      has_order?: Enum.any?(album.orders)
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "add_album_popup",
        %{},
        %{
          assigns: %{
            gallery_id: gallery_id,
            is_mobile: is_mobile
          }
        } = socket
      ) do
    socket
    |> open_modal(AlbumSettings, %{gallery_id: gallery_id, is_mobile: is_mobile})
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
        "Are you sure you wish to delete #{album.name}? Any photos within this album will be moved to your #{ngettext("Photos", "Unsorted photos", length(albums))}.",
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

  defdelegate handle_event(event, params, socket), to: PicselloWeb.GalleryLive.Shared

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
        |> put_flash(:success, "Album deleted successfully")
        |> noreply()

      _any ->
        socket
        |> close_modal()
        |> put_flash(:success, "Could not delete album")
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
      {:ok, {count, _}} ->
        socket
        |> close_modal()
        |> put_flash(
          :success,
          "#{count} unsorted #{ngettext("photo", "photos", count)} deleted successfully"
        )
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Could not delete photos")
        |> close_modal()
        |> noreply()
    end
  end

  @impl true
  def handle_info({:save, _}, %{assigns: %{gallery_id: gallery_id}} = socket) do
    socket
    |> close_modal()
    |> assign(:albums, Albums.get_albums_by_gallery_id(gallery_id))
    |> put_flash(:success, "Album thumbnail successfully updated")
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
    |> put_flash(:success, message)
    |> noreply()
  end

  @impl true
  def handle_info({:gallery_progress, %{total_progress: total_progress}}, socket) do
    socket
    |> assign(:total_progress, if(total_progress == 0, do: 1, else: total_progress))
    |> noreply()
  end

  @impl true
  def handle_info(
        {:photos_error, %{photos_error_count: photos_error_count, entries: entries}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    if length(entries) > 0, do: inprogress_upload_broadcast(gallery.id, entries)

    socket
    |> assign(:photos_error_count, photos_error_count)
    |> noreply()
  end

  @impl true
  def handle_info({:uploading, %{success_message: success_message}}, socket) do
    socket |> put_flash(:success, success_message) |> noreply()
  end

  @impl true
  def handle_info({:message_composed, message_changeset, recipients}, socket) do
    add_message_and_notify(socket, message_changeset, recipients, "gallery")
  end

  def thumbnail(%{album: %{thumbnail_photo: nil}} = assigns) do
    ~H"""
    <a class="mt-4 cursor-pointer albumBlock md:w-full h-72" style={"background-image: url('#{thumbnail_url(@album)}')"} phx-click={@event} phx-value-album={@album.id}>
      <div class="flex flex-row items-end justify-start h-full gap-2">
        <span class="font-sans font-bold text-white text-1xl"><%= @album.name %></span>
      </div>
    </a>
    """
  end

  def thumbnail(assigns) do
    ~H"""
    <a class="relative p-0 mt-4 bg-gray-200 cursor-pointer albumBlock h-72" phx-click={@event} phx-value-album={@album.id}>
      <img class="object-contain m-auto h-72" src={thumbnail_url(@album)} />
      <span class="absolute font-sans font-bold text-white bottom-4 left-4 text-1xl"><%= @album.name %></span>
    </a>
    """
  end

  defp thumbnail_url(%{thumbnail_photo: nil}), do: @blank_image
  defp thumbnail_url(%{thumbnail_photo: photo}), do: preview_url(photo)

  defp album_params(albums) do
    if List.last(albums).is_client_liked && length(albums) == 1,
      do: %{name: "All Photos", thumbnail_photo: nil, id: "unsorted-photos"},
      else: %{name: "Unsorted Photos", thumbnail_photo: nil, id: "unsorted-photos"}
  end
end
