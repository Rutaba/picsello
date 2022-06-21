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
  alias PicselloWeb.GalleryLive.Photos.{Photo, PhotoPreview, PhotoView, UploadError}
  alias PicselloWeb.GalleryLive.Albums.{AlbumThumbnail, AlbumSettings}

  @per_page 100
  @string_length 24

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      total_progress: 0,
      favorites_filter: false,
      page: 0,
      photos_error_count: 0,
      invalid_photos: [],
      pending_photos: [],
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
        "add_album_popup",
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
        "edit_album_thumbnail_popup",
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
        "set_album_thumbnail_popup",
        %{"photo_id" => photo_id},
        %{assigns: %{album: album}} = socket
      ) do
    opts = [
      event: "set_album_thumbnail",
      title: "Set as album thumbnail?",
      subtitle: "Are you sure you wish to set this photo as the thumbnail for #{album.name}?",
      confirm_label: "Yes, set as thumbnail",
      confirm_class: "btn-settings",
      icon: nil,
      payload: %{photo_id: photo_id}
    ]

    socket
    |> make_popup(opts)
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
  def handle_event("upload-failed", _, %{assigns: %{gallery: gallery, entries: entries}} = socket) do
    if length(entries) > 0, do: inprogress_upload_broadcast(gallery.id, entries)

    socket
    |> open_modal(UploadError, socket.assigns)
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
        "photo_preview_pop",
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
        "move_to_album_popup",
        %{"album_id" => album_id},
        %{
          assigns: %{
            gallery: gallery,
            selected_photos: selected_photos
          }
        } = socket
      ) do
    [album | _] =
      gallery.albums |> Enum.filter(fn %{id: id} -> id == String.to_integer(album_id) end)

    opts = [
      event: "move_to_album",
      title: "Move to album?",
      confirm_label: "Yes, move #{ngettext("photo", "photos", Enum.count(selected_photos))}",
      subtitle:
        "Are you sure you wish to move the selected #{ngettext("photo", "photos", Enum.count(selected_photos))} to #{album.name}?",
      payload: %{album_id: album_id}
    ]

    socket
    |> make_popup(opts)
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
    |> put_flash(:success, remove_from_album_success_message(selected_photos, album))
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  @impl true
  def handle_event(
        "remove_from_album_popup",
        %{"photo_id" => photo_id},
        %{assigns: %{album: album, selected_photos: selected_photos}} = socket
      ) do
    id =
      if Enum.empty?(selected_photos) do
        [photo_id]
      else
        selected_photos
      end

    opts = [
      event: "remove_from_album",
      title: "Remove from album?",
      confirm_label: "Yes, remove",
      subtitle:
        "Are you sure you wish to remove #{ngettext("this photo", "these photos", Enum.count(id))} from #{album.name}?",
      payload: %{photo_id: id}
    ]

    socket
    |> make_popup(opts)
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
    |> assign(:update_mode, "append")
    |> assign(page: page + 1)
    |> assign_photos(@per_page)
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  @impl true
  def handle_event("toggle_favorites", _, socket) do
    socket
    |> assign(:selected_photos, [])
    |> push_event("select_mode", %{"mode" => "selected_none"})
    |> assign(:select_mode, "selected_none")
    |> toggle_favorites(@per_page)
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
  def handle_event("delete_photo_popup", %{"photo_id" => photo_id}, socket) do
    opts = [
      event: "delete_photo",
      title: "Delete this photo?",
      subtitle:
        "Are you sure you wish to permanently delete this photo from #{socket.assigns.gallery.name} ?",
      payload: %{photo_id: photo_id}
    ]

    socket
    |> make_popup(opts)
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
    |> make_popup(opts)
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
    |> push_event("reload_grid", %{})
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
    |> push_event("reload_grid", %{})
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
    |> put_flash(:success, message)
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
        {:confirm_event, "remove_from_album", %{photo_id: id}},
        %{
          assigns: %{
            album: album
          }
        } = socket
      ) do
    Galleries.remove_photos_from_album(id)

    socket
    |> close_modal()
    |> assign(:selected_photos, [])
    |> push_event("remove_items", %{"ids" => id})
    |> assign_photos(@per_page)
    |> put_flash(:success, remove_from_album_success_message(id, album))
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "move_to_album", %{album_id: album_id}},
        %{assigns: %{selected_photos: selected_photos, gallery: gallery}} = socket
      ) do
    Galleries.move_to_album(String.to_integer(album_id), selected_photos)

    socket
    |> close_modal()
    |> assign(:selected_photos, [])
    |> push_event("remove_items", %{"ids" => selected_photos})
    |> assign_photos(@per_page)
    |> put_flash(
      :success,
      move_to_album_success_message(selected_photos, album_id, gallery)
    )
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "set_album_thumbnail", %{photo_id: photo_id}},
        %{
          assigns: %{
            album: album
          }
        } = socket
      ) do
    thumbnail = Galleries.get_photo(String.to_integer(photo_id))
    album |> Repo.preload([:photos, :thumbnail_photo]) |> Albums.save_thumbnail(thumbnail)

    socket
    |> close_modal()
    |> put_flash(:success, "Album thumbnail successfully updated")
    |> noreply()
  end

  @impl true
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
  end

  @impl true
  def handle_info(
        {:photos_error,
         %{
           invalid_photos: invalid_photos,
           pending_photos: pending_photos,
           photos_error_count: photos_error_count,
           entries: entries
         }},
        socket
      ) do
    socket
    |> assign(:entries, entries)
    |> assign(:invalid_photos, invalid_photos)
    |> assign(:pending_photos, pending_photos)
    |> assign(:photos_error_count, photos_error_count)
    |> noreply()
  end

  @impl true
  def handle_info(:photo_upload_completed, socket) do
    socket
    |> assign(:update_mode, "append")
    |> assign_photos(@per_page)
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  @impl true
  def handle_info({:upload_success_message, success_message}, socket) do
    socket |> put_flash(:success, success_message) |> noreply()
  end

  @impl true
  def handle_info({:save, %{message: message}}, socket) do
    socket
    |> close_modal()
    |> put_flash(:success, message)
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
    with {:ok, {count, _}} <- Galleries.delete_photos(selected_photos),
         {:ok, gallery} <-
           Galleries.update_gallery(gallery, %{
             total_count: gallery.total_count - count
           }) do
      socket
      |> assign(:gallery, gallery)
      |> assign(:selected_photos, [])
      |> close_modal()
      |> push_event("remove_items", %{"ids" => selected_photos})
      |> push_event("select_mode", %{"mode" => "selected_none"})
      |> put_flash(
        :success,
        "#{count} #{ngettext("photo", "photos", count)} deleted successfully"
      )
      |> assign_photos(@per_page)
      |> push_event("reload_grid", %{})
      |> noreply()
    else
      _ ->
        socket
        |> put_flash(:error, "Could not delete photos")
        |> close_modal()
        |> noreply()
    end
  end

  defp move_to_album_success_message(selected_photos, album_id, gallery) do
    [album | _] =
      gallery.albums |> Enum.filter(fn %{id: id} -> id == String.to_integer(album_id) end)

    photos_count = length(selected_photos)

    "#{photos_count} #{ngettext("photo", "photos", photos_count)} successfully moved to #{album.name}"
  end

  defp remove_from_album_success_message(selected_photos, album) do
    photos_count = length(selected_photos)

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

  defp truncate(string) do
    case get_class(string) do
      "tooltip" ->
        String.slice(string, 0..@string_length) <> "..."

      _ ->
        string
    end
  end

  defp get_class(string), do: if(String.length(string) > @string_length, do: "tooltip", else: nil)

  defp album_actions(assigns) do
    assigns = assigns |> Enum.into(%{exclude_album_id: nil})

    ~H"""
    <%= for album <- @albums do %>
      <%= if @exclude_album_id != album.id do %>
        <li class={"relative py-1.5 hover:bg-blue-planning-100 #{get_class(album.name)}"}>
          <button class="album-actions" phx-click="move_to_album_popup" phx-value-album_id={album.id}>Move to <%= truncate(album.name) %></button>
          <div class="cursor-default tooltiptext">Move to <%= album.name %></div>
        </li>
      <% end %>
    <% end %>
    """
  end

  defp grid_padding(photos_error_count, album, gallery) do
    cond do
      photos_error_count > 0 ->
        "pt-56"

      !!album ->
        "lg:pt-40 pt-48"

      Enum.any?(gallery.albums) ->
        "lg:pt-40 pt-32"

      true ->
        "pt-40"
    end
  end
end
