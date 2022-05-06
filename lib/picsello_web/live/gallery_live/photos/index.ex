defmodule PicselloWeb.GalleryLive.Photos.Index do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_photographer"
    ]

  import PicselloWeb.LiveHelpers
  import PicselloWeb.GalleryLive.Shared
  import PicselloWeb.Gettext, only: [ngettext: 3]

  alias Phoenix.PubSub
  alias Picsello.{Repo, Galleries, Albums}
  alias Picsello.Galleries.Workers.PositionNormalizer
  alias PicselloWeb.GalleryLive.Photos.{PhotoPreview, PhotoView}
  alias PicselloWeb.GalleryLive.Albums.{AlbumThumbnail, AlbumSettings}

  @per_page 24

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      total_progress: 0,
      favorites_filter: false,
      page: 0,
      photo_updates: "false",
      select_mode: "selected_none",
      update_mode: "append",
      selected_photos: []
    )
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => gallery_id, "album_id" => album_id}, _, socket) do
    album = Albums.get_album!(album_id) |> Repo.preload(:photos)

    socket
    |> assigns(gallery_id, album)
  end

  @impl true
  def handle_params(%{"id" => gallery_id}, _, socket) do
    socket
    |> assigns(gallery_id)
  end

  @impl true
  def handle_event(
        "albums_popup",
        %{},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> open_modal(AlbumSettings, %{gallery_id: gallery.id})
    |> noreply()
  end

  @impl true
  def handle_event(
        "album_thumbnail_popup",
        _,
        %{
          assigns: %{
            gallery: gallery,
            album: album
          }
        } = socket
      ) do
    socket
    |> open_modal(AlbumThumbnail, %{album_id: album.id, gallery_id: gallery.id})
    |> noreply()
  end

  @impl true
  def handle_event(
        "album_settings_popup",
        _,
        %{
          assigns: %{
            gallery: gallery,
            album: album
          }
        } = socket
      ) do
    socket
    |> open_modal(AlbumSettings, %{gallery_id: gallery.id, album: album, target: self()})
    |> noreply()
  end

  @impl true
  def handle_event("upload-failed", _, socket) do
    socket
    |> open_modal(UploadComponent, socket.assigns)
    |> noreply
  end

  @impl true
  def handle_event("photo_view", %{"photo_id" => photo_id}, socket) do
    socket
    |> open_modal(PhotoView, %{photo_id: photo_id})
    |> noreply
  end

  @impl true
  def handle_event(
        "photo_preview",
        %{"photo_id" => photo_id},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> open_modal(
      PhotoPreview,
      %{
        gallery: gallery,
        photo_id: photo_id
      }
    )
    |> noreply
  end

  @impl true
  def handle_event(
        "move_to_album",
        %{"album_id" => album_id},
        %{
          assigns: %{
            gallery: gallery,
            selected_photos: selected_photos
          }
        } = socket
      ) do
    Galleries.move_to_album(String.to_integer(album_id), selected_photos)

    socket
    |> assign(:selected_photos, [])
    |> push_event("remove_items", %{"ids" => selected_photos})
    |> assign_photos(@per_page)
    |> put_flash(
      :gallery_success,
      move_to_album_success_message(selected_photos, album_id, gallery)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "remove_from_album",
        _,
        %{
          assigns: %{
            album: album,
            selected_photos: selected_photos
          }
        } = socket
      ) do
    Galleries.remove_photos_from_album(selected_photos)

    socket
    |> assign(:selected_photos, [])
    |> push_event("remove_items", %{"ids" => selected_photos})
    |> assign_photos(@per_page)
    |> put_flash(:gallery_success, remove_from_album_success_message(selected_photos, album))
    |> noreply()
  end

  @impl true
  def handle_event(
        "load-more",
        _,
        %{
          assigns: %{
            page: page
          }
        } = socket
      ) do
    socket
    |> assign(page: page + 1)
    |> assign_photos(@per_page)
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle_favorites",
        _,
        %{
          assigns: %{
            favorites_filter: favorites_filter
          }
        } = socket
      ) do
    toggle_state = !favorites_filter

    socket
    |> assign(:page, 0)
    |> assign(:favorites_filter, toggle_state)
    |> then(fn socket ->
      case toggle_state do
        true ->
          socket
          |> assign(:update_mode, "replace")

        _ ->
          socket
          |> assign(:update_mode, "append")
      end
    end)
    |> assign(:selected_photos, [])
    |> push_event("select_mode", %{"mode" => "selected_none"})
    |> assign(:select_mode, "selected_none")
    |> assign_photos(@per_page)
    |> noreply()
  end

  @impl true
  def handle_event(
        "update_photo_position",
        %{"photo_id" => photo_id, "type" => type, "args" => args},
        %{
          assigns: %{
            gallery: %{
              id: gallery_id
            }
          }
        } = socket
      ) do
    Galleries.update_gallery_photo_position(
      gallery_id,
      photo_id
      |> String.to_integer(),
      type,
      args
    )

    PositionNormalizer.normalize(gallery_id)

    noreply(socket)
  end

  @impl true
  def handle_event("delete_photo_popup", %{"id" => id}, socket) do
    opts = [
      event: "delete_photo",
      title: "Delete this photo?",
      subtitle:
        "Are you sure you wish to permanently delete this photo from #{socket.assigns.gallery.name} ?",
      payload: %{photo_id: id}
    ]

    socket
    |> make_delete_popup(opts)
  end

  @impl true
  def handle_event("delete_selected_photos_popup", _, socket) do
    opts = [
      event: "delete_selected_photos",
      title: "Delete selected photos?",
      subtitle:
        "Are you sure you wish to permanently delete selected photos from #{socket.assigns.gallery.name} ?"
    ]

    socket
    |> make_delete_popup(opts)
  end

  @impl true
  def handle_event(
        "selected_all",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    photo_ids = Galleries.get_gallery_photo_ids(gallery.id, make_opts(socket, @per_page))

    socket
    |> push_event("select_mode", %{"mode" => "selected_all"})
    |> assign(:selected_photos, photo_ids)
    |> assign(:select_mode, "selected_all")
    |> noreply
  end

  @impl true
  def handle_event("selected_none", _, socket) do
    socket
    |> then(fn
      %{
        assigns: %{
          favorites_filter: true
        }
      } = socket ->
        socket
        |> assign(:page, 0)
        |> assign(:update_mode, "append")
        |> assign(:favorites_filter, false)
        |> assign_photos(@per_page)

      socket ->
        socket
    end)
    |> push_event("select_mode", %{"mode" => "selected_none"})
    |> assign(:select_mode, "selected_none")
    |> assign(:selected_photos, [])
    |> noreply
  end

  @impl true
  def handle_event(
        "selected_favorite",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, true)
    |> then(fn socket ->
      photo_ids = Galleries.get_gallery_photo_ids(gallery.id, make_opts(socket, @per_page))

      socket
      |> assign(:selected_photos, photo_ids)
    end)
    |> push_event("select_mode", %{"mode" => "selected_favorite"})
    |> assign(:select_mode, "selected_favorite")
    |> assign_photos(@per_page)
    |> noreply
  end

  @impl true
  def handle_event(
        "toggle_selected_photos",
        %{"photo_id" => photo_id},
        %{assigns: %{selected_photos: selected_photos}} = socket
      ) do
    photo_id = String.to_integer(photo_id)

    selected_photos =
      if Enum.member?(selected_photos, photo_id) do
        List.delete(selected_photos, photo_id)
      else
        [photo_id | selected_photos]
      end

    socket
    |> assign(:selected_photos, selected_photos)
    |> noreply()
  end

  @impl true
  def handle_event("client-link", _, socket) do
    share_gallery(socket)
  end

  @impl true
  def handle_info({:album_settings, %{message: message, album: album}}, socket) do
    socket
    |> close_modal()
    |> assign(:album, album |> Repo.preload(:photos))
    |> put_flash(:gallery_success, message)
    |> noreply()
  end

  @impl true
  def handle_info({:photo_processed, _, photo}, socket) do
    photo_update =
      %{
        id: photo.id,
        url: preview_url(photo)
      }
      |> Jason.encode!()

    socket
    |> assign(:photo_updates, photo_update)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_photo", %{photo_id: id}},
        socket
      ) do
    delete_photos(socket, [id])
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_selected_photos", _},
        %{assigns: %{selected_photos: selected_photos}} = socket
      ) do
    delete_photos(socket, selected_photos)
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_album", %{album_id: album_id}},
        %{assigns: %{gallery: %{id: gallery_id}}} = socket
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
  def handle_info({:total_progress, total_progress}, socket) do
    socket
    |> assign(:total_progress, total_progress)
    |> noreply()
  end

  @impl true
  def handle_info(:photo_upload_completed, socket) do
    socket
    |> assign_photos(@per_page)
    |> noreply()
  end

  @impl true
  def handle_info({:upload_success_message, success_message}, socket) do
    socket |> put_flash(:gallery_success, success_message) |> noreply()
  end

  @impl true
  def handle_info({:save, %{message: message}}, socket) do
    socket
    |> close_modal()
    |> put_flash(:gallery_success, message)
    |> assign_photos(@per_page)
    |> noreply
  end

  @impl true
  def handle_info({:message_composed, message_changeset}, socket) do
    add_message_and_notify(socket, message_changeset)
  end

  defp assigns(socket, gallery_id, album \\ nil) do
    gallery =
      Galleries.get_gallery!(gallery_id)
      |> Repo.preload(:albums)
      |> Galleries.load_watermark_in_gallery()

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery_id}")
      PubSub.subscribe(Picsello.PubSub, "photo_uploaded:#{gallery_id}")
    end

    socket
    |> assign(
      favorites_count: Galleries.gallery_favorites_count(gallery),
      gallery: gallery,
      album: album,
      page_title: page_title(socket.assigns.live_action),
      products: Galleries.products(gallery)
    )
    |> assign_photos(@per_page)
    |> noreply()
  end

  defp delete_photos(%{assigns: %{gallery: gallery}} = socket, selected_photos) do
    with {:ok, _} <- Galleries.delete_photos(selected_photos),
         {:ok, gallery} <-
           Galleries.update_gallery(gallery, %{
             total_count: gallery.total_count - total(selected_photos)
           }) do
      socket
      |> assign(:gallery, gallery)
      |> assign(:selected_photos, [])
      |> close_modal()
      |> push_event("remove_items", %{"ids" => selected_photos})
      |> put_flash(
        :gallery_success,
        "#{total(selected_photos)} #{ngettext("photo", "photos", Enum.count(selected_photos))} deleted successfully"
      )
      |> assign_photos(@per_page)
      |> noreply()
    else
      _ ->
        socket
        |> put_flash(:gallery_success, "Could not delete photos")
        |> close_modal()
        |> noreply()
    end
  end

  defp move_to_album_success_message(selected_photos, album_id, gallery) do
    [album | _] =
      gallery.albums |> Enum.filter(fn %{id: id} -> id == String.to_integer(album_id) end)

    photos_count = total(selected_photos)

    "#{photos_count} #{ngettext("photo", "photos", photos_count)} successfully moved to #{album.name}"
  end

  defp remove_from_album_success_message(selected_photos, album) do
    photos_count = total(selected_photos)

    "#{photos_count} #{ngettext("photo", "photos", photos_count)} successfully removed from #{album.name}"
  end

  defp options(:select),
    do: [
      %{title: "All", id: "selected_all"},
      %{title: "Favorite", id: "selected_favorite"},
      %{title: "None", id: "selected_none"}
    ]

  defp page_title(:index), do: "Photos"
  defp page_title(:edit), do: "Edit Photos"
  defp page_title(:upload), do: "New Photos"

  defp extract_album(album, album_return, other) do
    if album, do: Map.get(album, album_return), else: other
  end

  defp album_actions(assigns) do
    assigns = assigns |> Enum.into(%{exclude_album_id: nil})

    ~H"""
    <%= for album <- @albums do %>
      <%= if @exclude_album_id != album.id do %>
      <li class="relative">
        <button class="album-actions" phx-click="move_to_album" phx-value-album_id={album.id}>Move to <%= album.name %></button>
      </li>
      <% end %>
    <% end %>
    """
  end
end
