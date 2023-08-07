defmodule PicselloWeb.GalleryLive.Photos.Index do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_photographer"
    ]

  import PicselloWeb.Live.Shared, only: [make_popup: 2]
  import PicselloWeb.GalleryLive.Shared
  import PicselloWeb.Gettext, only: [ngettext: 3]
  import PicselloWeb.Shared.StickyUpload, only: [sticky_upload: 1]
  import PicselloWeb.GalleryLive.Photos.Toggle, only: [toggle: 1]
  import PicselloWeb.GalleryLive.Photos.ProofingGrid, only: [proofing_grid: 1]

  alias Phoenix.PubSub

  alias Picsello.{
    Repo,
    Galleries,
    Albums,
    Orders,
    Galleries.Watermark,
    Notifiers.UserNotifier,
    Utils
  }

  alias Picsello.Galleries.Workers.PositionNormalizer
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias PicselloWeb.GalleryLive.Photos.FolderUpload
  alias PicselloWeb.GalleryLive.Photos.{Photo, PhotoPreview, PhotoView, UploadError}
  alias PicselloWeb.GalleryLive.Albums.{AlbumThumbnail, AlbumSettings}
  alias Ecto.Multi

  @per_page 500
  @string_length 24

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      albums_length: 0,
      show_favorite_toggle: false,
      total_progress: 0,
      favorites_filter: false,
      photographer_favorites_filter: false,
      client_liked_album: false,
      page: 0,
      photos_error_count: 0,
      inprogress_photos: [],
      url: Routes.static_path(PicselloWeb.Endpoint, "/images/gallery-icon.svg"),
      invalid_photos: [],
      pending_photos: [],
      photo_updates: "false",
      select_mode: "selected_none",
      update_mode: "append",
      selected_photos: [],
      selections: [],
      selection_filter: false,
      orders: [],
      selected_photo_id: nil,
      first_visit?: false
    )
    |> ok()
  end

  @impl true

  def handle_params(
        %{"id" => gallery_id, "album_id" => "client_liked"} = params,
        _,
        socket
      ) do
    albums_length = length(get_all_gallery_albums(gallery_id))

    socket
    |> is_mobile(params)
    |> assign(:client_liked_album, true)
    |> assign(:favorites_filter, true)
    |> assign(:albums_length, albums_length)
    |> assigns(gallery_id, client_liked_album(gallery_id))
  end

  def handle_params(
        %{"id" => gallery_id, "album_id" => album_id} = params,
        _,
        %{assigns: %{current_user: %{organization: organization}}} = socket
      ) do
    album = Albums.get_album!(album_id) |> Repo.preload(:photos)
    orders = Orders.get_proofing_order_photos(album.id, organization.id)

    socket
    |> assign(orders: orders)
    |> assign(selection_filter: orders != [])
    |> is_mobile(params)
    |> assigns(gallery_id, album)
    |> maybe_has_selected_photo(params)
  end

  def handle_params(%{"id" => gallery_id} = params, _, socket) do
    socket
    |> is_mobile(params)
    |> assigns(gallery_id)
    |> maybe_has_selected_photo(params)
  end

  @impl true
  def handle_event("back_to_navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket |> assign(:is_mobile, !is_mobile) |> noreply
  end

  def handle_event(
        "add_album_popup",
        %{},
        %{
          assigns: %{
            gallery: gallery,
            selected_photos: selected_photos,
            client_liked_album: client_liked_album
          }
        } = socket
      ) do
    socket
    |> open_modal(AlbumSettings, %{
      gallery_id: gallery.id,
      selected_photos: selected_photos,
      is_redirect: !client_liked_album
    })
    |> noreply()
  end

  def handle_event(
        "assign_to_album_popup",
        %{},
        %{
          assigns: %{
            gallery: gallery,
            selected_photos: selected_photos,
            photos: photos
          }
        } = socket
      ) do
    dropdown_items =
      gallery
      |> Repo.preload(:albums)
      |> Map.get(:albums)
      |> then(fn albums ->
        case selected_photos do
          [photo_id] ->
            photo = Enum.find(photos, &(&1.id == photo_id))
            Enum.reject(albums, &(&1.id == photo.album_id))

          _ ->
            albums
        end
      end)
      |> Enum.map(&{&1.name, &1.id})

    opts = [
      event: "assign_to_album",
      title: "Assign to album",
      confirm_label: "Save changes",
      close_label: "Cancel",
      subtitle:
        "If you'd like, you can reassign all the selected photos from their  current locations to a
          new album of your choice",
      dropdown?: true,
      dropdown_label: "Assign to which album?",
      dropdown_items: dropdown_items
    ]

    socket
    |> make_popup(opts)
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

  def handle_event(
        "album_settings_popup",
        _,
        %{
          assigns: %{
            gallery: gallery,
            album: album,
            orders: orders
          }
        } = socket
      ) do
    socket
    |> open_modal(AlbumSettings, %{
      gallery_id: gallery.id,
      album: album,
      target: self(),
      has_order?: Enum.any?(orders)
    })
    |> noreply()
  end

  def handle_event(
        "downlaod_photos",
        _,
        %{
          assigns: %{
            gallery: gallery,
            selected_photos: selected_photos,
            current_user: current_user
          }
        } = socket
      ) do
    UserNotifier.deliver_download_start_notification(current_user, gallery)
    Galleries.pack(gallery, selected_photos, user_email: current_user.email)

    socket
    |> push_event("select_mode", %{"mode" => "selected_none"})
    |> assign(:select_mode, "selected_none")
    |> assign(:selected_photos, [])
    |> push_event("reload_grid", %{})
    |> put_flash(
      :success,
      "Download request sent at #{current_user.email}! The ZIP file with your images is on the way to your inbox"
    )
    |> noreply()
  end

  @impl true
  def handle_event("upload-failed", _, %{assigns: %{gallery: gallery, entries: entries}} = socket) do
    if length(entries) > 0, do: inprogress_upload_broadcast(gallery.id, entries)

    socket
    |> open_modal(UploadError, socket.assigns)
    |> noreply
  end

  def handle_event("photo_view", %{"photo_id" => photo_id}, %{assigns: assigns} = socket) do
    socket
    |> open_modal(
      PhotoView,
      %{
        photo_id: photo_id,
        from: :photographer,
        is_proofing: false,
        photo_ids:
          assigns.photo_ids
          |> CLL.init()
          |> CLL.next(Enum.find_index(assigns.photo_ids, &(&1 == photo_id)) || 0)
      }
    )
    |> noreply
  end

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

  def handle_event(
        "remove_from_album",
        _,
        %{
          assigns: %{
            album: album,
            selected_photos: selected_photos,
            gallery: %{id: gallery_id}
          }
        } = socket
      ) do
    Galleries.remove_photos_from_album(selected_photos, gallery_id)

    socket
    |> assign(:selected_photos, [])
    |> push_event("remove_items", %{"ids" => selected_photos})
    |> assign_photos(@per_page)
    |> sorted_photos()
    |> put_flash(:success, remove_from_album_success_message(selected_photos, album))
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  def handle_event(
        "remove_from_album_popup",
        %{"photo_id" => photo_id},
        %{assigns: %{album: album, selected_photos: selected_photos}} = socket
      ) do
    ids =
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
        "Are you sure you wish to remove #{ngettext("this photo", "these photos", Enum.count(ids))} from #{album.name}?",
      payload: %{photo_id: ids}
    ]

    socket
    |> make_popup(opts)
  end

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
    |> sorted_photos()
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle_selections",
        _,
        %{
          assigns: %{selection_filter: selection_filter}
        } = socket
      ) do
    socket
    |> push_event("select_mode", %{"mode" => "selected_none"})
    |> assign(
      selected_photos: [],
      select_mode: "selected_none",
      selection_filter: !selection_filter,
      page: 0,
      update_mode: "replace"
    )
    |> assign_photos(@per_page)
    |> sorted_photos()
    |> push_event("select_mode", %{"mode" => "selected_none"})
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  def handle_event("toggle_favorites", _, socket) do
    socket
    |> assign(:selected_photos, [])
    |> assign(:inprogress_photos, [])
    |> push_event("select_mode", %{"mode" => "selected_none"})
    |> assign(:select_mode, "selected_none")
    |> toggle_photographer_favorites(@per_page)
  end

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

  def handle_event(
        "selected_all",
        _,
        %{
          assigns:
            %{
              gallery: gallery,
              current_user: %{organization: organization}
            } = assigns
        } = socket
      ) do
    selection_filter = assigns[:selection_filter] || false
    album = assigns[:album] || nil

    photo_ids =
      if selection_filter && album do
        Orders.get_proofing_order_photos(album.id, organization.id)
        |> Enum.flat_map(fn %{digitals: digitals} ->
          Enum.map(digitals, & &1.photo.id)
        end)
      else
        Galleries.get_gallery_photo_ids(gallery.id, make_opts(socket, @per_page))
      end

    socket
    |> push_event("select_mode", %{"mode" => "selected_all"})
    |> assign(:selected_photos, photo_ids)
    |> assign(:select_mode, "selected_all")
    |> noreply
  end

  def handle_event("selected_none", _, socket) do
    socket
    |> then(fn
      %{
        assigns: %{
          photographer_favorites_filter: true
        }
      } = socket ->
        socket
        |> assign(:page, 0)
        |> assign(:update_mode, "append")
        |> assign(:photographer_favorites_filter, false)
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
    |> assign(:photographer_favorites_filter, true)
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
        %{
          assigns: %{
            selected_photos: selected_photos,
            orders: orders
          }
        } = socket
      ) do
    photo_id = String.to_integer(photo_id)

    order_photo_ids =
      case orders do
        [] ->
          []

        orders ->
          Enum.flat_map(orders, fn %{digitals: digitals} ->
            Enum.map(digitals, & &1.photo.id)
          end)
      end

    selected_photos =
      if Enum.member?(order_photo_ids, photo_id) do
        selected_photos
      else
        if Enum.member?(selected_photos, photo_id) do
          List.delete(selected_photos, photo_id)
        else
          [photo_id | selected_photos]
        end
      end

    socket
    |> assign(:selected_photos, selected_photos)
    |> noreply()
  end

  @impl true
  def handle_event("gallery-created", %{"galleryType" => "finals"}, socket) do
    socket |> assign(:first_visit?, true) |> noreply()
  end

  @impl true
  def handle_event("gallery-created", %{"galleryType" => type}, socket) do
    {title, subtitle} = success_component_items()[type]

    socket
    |> PicselloWeb.SuccessComponent.open(%{
      title: title,
      subtitle: subtitle,
      close_label: "Great!",
      close_class: "bg-black text-white",
      for: type
    })
    |> noreply()
  end

  def handle_event(
        "folder-information",
        %{"folder" => folder, "sub_folders" => sub_folders},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> open_modal(FolderUpload, %{folder: folder, sub_folders: sub_folders, gallery: gallery})
    |> noreply()
  end

  @impl true
  defdelegate handle_event(event, params, socket), to: PicselloWeb.GalleryLive.Shared

  @impl true
  def handle_info({:album_settings, %{message: message, album: album}}, socket) do
    socket
    |> close_modal()
    |> assign(:album, album |> Repo.preload(:photos))
    |> put_flash(:success, message)
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "delete_photo", %{photo_id: id}},
        socket
      ) do
    delete_photos(socket, [id])
  end

  def handle_info(
        {:confirm_event, "delete_selected_photos", _},
        %{assigns: %{selected_photos: selected_photos}} = socket
      ) do
    delete_photos(socket, selected_photos)
  end

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

  def handle_info(
        {:confirm_event, "remove_from_album", %{photo_id: ids}},
        %{
          assigns: %{
            album: album,
            gallery: %{id: gallery_id}
          }
        } = socket
      ) do
    Galleries.remove_photos_from_album(ids, gallery_id)

    socket
    |> close_modal()
    |> assign(:selected_photos, [])
    |> push_event("remove_items", %{"ids" => ids})
    |> assign_photos(@per_page)
    |> sorted_photos()
    |> put_flash(:success, remove_from_album_success_message(ids, album))
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "move_to_album", %{album_id: album_id}},
        %{assigns: %{selected_photos: selected_photos, gallery: gallery}} = socket
      ) do
    album = Albums.get_album!(album_id)

    selected_photos =
      if album.is_finals do
        selected_photos
      else
        duplicate_photo_ids =
          Galleries.get_selected_photos_name(selected_photos)
          |> Galleries.filter_duplication(album_id)

        Galleries.delete_photos_by(duplicate_photo_ids)

        selected_photos -- duplicate_photo_ids
      end

    Galleries.move_to_album(String.to_integer(album_id), selected_photos)

    if album.is_proofing && is_nil(gallery.watermark) do
      %{job: %{client: %{organization: %{name: name}}}} = Galleries.populate_organization(gallery)

      gallery
      |> Galleries.get_photos_by_ids(selected_photos)
      |> Enum.each(&ProcessingManager.start(&1, Watermark.build(name, gallery)))
    end

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

  def handle_info(
        {:photo_processed, _, photo},
        %{assigns: %{total_progress: total_progress}} = socket
      ) do
    if total_progress == 100 || total_progress == 0 do
      photo_update =
        %{
          id: photo.id,
          url: preview_url(photo)
        }
        |> Jason.encode!()

      socket |> assign(:photo_updates, photo_update)
    else
      socket
    end
    |> noreply()
  end

  def handle_info(
        {:gallery_progress, %{total_progress: total_progress, entries: entries}},
        %{assigns: %{inprogress_photos: inprogress_photos}} = socket
      ) do
    cond do
      inprogress_photos == [] ->
        socket
        |> assign(:update_mode, "ignore")
        |> assign(:inprogress_photos, entries)
        |> push_event("reload_grid", %{})

      total_progress == 100 ->
        socket |> assign(:update_mode, "append")

      true ->
        socket |> assign(:update_mode, "ignore")
    end
    |> assign(:total_progress, total_progress)
    |> noreply()
  end

  def handle_info(
        {:uploading, %{pid: pid, entries: entries, uploading: true}},
        %{assigns: %{current_user: user, gallery: gallery}} = socket
      ) do
    remove_cache(user.id, gallery.id)
    add_cache(socket, pid)

    socket
    |> assign(:update_mode, "ignore")
    |> assign(:inprogress_photos, entries)
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  def handle_info({:uploading, %{success_message: success_message}}, socket) do
    socket
    |> push_event("remove_loader", %{})
    |> assign(:update_mode, "append")
    |> assign(:inprogress_photos, [])
    |> assign_photos(@per_page)
    |> sorted_photos()
    |> push_event("reload_grid", %{})
    |> put_flash(:success, success_message)
    |> noreply()
  end

  def handle_info(:clear_photos_error, %{assigns: %{total_progress: total_progress}} = socket) do
    if total_progress == 0 do
      socket
      |> assign(:inprogress_photos, [])
      |> assign(:update_mode, "append")
      |> push_event("remove_loader", %{})
      |> assign(:photos_error_count, 0)
    else
      socket
      |> assign(:photos_error_count, 0)
    end
    |> noreply()
  end

  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
  end

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

  def handle_info(:photo_upload_completed, socket) do
    socket
    |> assign(:update_mode, "append")
    |> assign_photos(@per_page)
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  def handle_info({:upload_success_message, success_message}, socket) do
    socket |> put_flash(:success, success_message) |> noreply()
  end

  def handle_info({:save, %{message: message}}, socket) do
    socket
    |> close_modal()
    |> put_flash(:success, message)
    |> assign_photos(@per_page)
    |> noreply()
  end

  def handle_info({:message_composed, message_changeset, recipients}, socket) do
    add_message_and_notify(socket, message_changeset, recipients, "gallery")
  end

  @impl true
  def handle_info({:message_composed_for_album, message_changeset, recipients}, socket) do
    add_message_and_notify(socket, message_changeset, recipients, "album")
  end

  def handle_info({:pack, _, _}, socket), do: noreply(socket)

  def handle_info(
        {
          :confirm_event,
          "assign_to_album",
          %{item_id: item_id}
        },
        %{assigns: %{gallery: %{albums: albums}}} = socket
      ) do
    album = Enum.find(albums, &(to_string(&1.id) == item_id))

    opts = [
      event: "assign_album_confirmation",
      title: "Move photo",
      subtitle: "Are you sure you wish to to move selected photos from its current location to
            #{album.name} ?",
      confirm_label: "Yes, move",
      payload: %{album_id: album.id}
    ]

    socket
    |> make_popup(opts)
  end

  def handle_info(
        {
          :confirm_event,
          "add_from_clients_favorite",
          %{album: album} = params
        },
        socket
      ) do
    create_album(album, params, socket)
  end

  def handle_info(
        {
          :confirm_event,
          "assign_album_confirmation",
          %{album_id: album_id}
        },
        %{assigns: %{selected_photos: selected_photos, gallery: %{albums: albums}}} = socket
      ) do
    album = Enum.find(albums, &(&1.id == album_id))
    Galleries.move_to_album(album_id, selected_photos)

    socket
    |> put_flash(:success, "Photos successfully moved to #{album.name}")
    |> close_modal()
    |> noreply()
  end

  def handle_info(:update_photo_gallery_state, socket) do
    socket
    |> assign_show_favorite_toggle()
    |> noreply()
  end

  defp assigns(socket, gallery_id, album \\ nil) do
    gallery = get_gallery!(gallery_id)

    if connected?(socket) do
      Galleries.subscribe(gallery)
      PubSub.subscribe(Picsello.PubSub, "clear_photos_error:#{gallery_id}")
      PubSub.subscribe(Picsello.PubSub, "photo_uploaded:#{gallery_id}")
      PubSub.subscribe(Picsello.PubSub, "uploading:#{gallery_id}")
    end

    currency = Picsello.Currency.for_gallery(gallery)

    socket
    |> assign(
      favorites_count: Galleries.gallery_favorites_count(gallery),
      show_products: currency in Utils.products_currency(),
      gallery: gallery,
      album: album,
      page_title: page_title(socket.assigns.live_action),
      products: Galleries.products(gallery)
    )
    |> assign_photos(@per_page)
    |> then(&assign(&1, photo_ids: Enum.map(&1.assigns.photos, fn photo -> photo.id end)))
    |> sorted_photos()
    |> assign_show_favorite_toggle()
    |> noreply()
  end

  defp assign_show_favorite_toggle(%{assigns: %{gallery: %{id: id}} = assigns} = socket) do
    opts =
      assigns
      |> Map.get(:album)
      |> photos_album_opts()
      |> Keyword.put(:photographer_favorites_filter, true)

    show_favorite_toggle = Galleries.get_gallery_photos(id, opts) |> Enum.count() > 0

    assign(socket, show_favorite_toggle: show_favorite_toggle)
  end

  defp get_gallery!(gallery_id) do
    gallery_id
    |> Galleries.get_gallery!()
    |> Repo.preload([:albums, :photographer])
    |> Galleries.load_watermark_in_gallery()
  end

  defp maybe_has_selected_photo({:noreply, socket}, params) do
    params
    |> case do
      %{"go_to_original" => "true", "photo_id" => photo_id} ->
        photo_id = String.to_integer(photo_id)

        socket
        |> assign(:selected_photos, [photo_id])
        |> assign(:selected_photo_id, photo_id)

      _ ->
        socket
    end
    |> noreply()
  end

  defp sorted_photos(%{assigns: %{orders: orders, photos: photos}} = socket) do
    case orders do
      [] ->
        assign(socket, photos: photos)

      orders ->
        photo_ids =
          Enum.flat_map(orders, fn %{digitals: digitals} ->
            Enum.map(digitals, & &1.photo.id)
          end)

        photos = Enum.reject(photos, &(&1.id in photo_ids))
        assign(socket, photos: photos)
    end
  end

  defp delete_photos(%{assigns: %{gallery: %{id: gallery_id}}} = socket, selected_photos) do
    %{total_count: total_count} = gallery = get_gallery!(gallery_id)

    Multi.new()
    |> Multi.run(:delete_photos, fn _, _ -> Galleries.delete_photos(selected_photos) end)
    |> Multi.run(:update_gallery, fn _, %{delete_photos: {count, _}} ->
      Galleries.update_gallery(gallery, %{total_count: total_count - count})
    end)
    |> Repo.transaction()
    |> then(fn
      {:ok, %{update_gallery: gallery, delete_photos: {count, _}}} ->
        socket
        |> assign(:gallery, gallery)
        |> assign(:selected_photos, [])
        |> push_event("remove_items", %{"ids" => selected_photos})
        |> push_event("select_mode", %{"mode" => "selected_none"})
        |> put_flash(
          :success,
          "#{count} #{ngettext("photo", "photos", count)} deleted successfully"
        )
        |> assign_photos(@per_page)
        |> sorted_photos()
        |> push_event("reload_grid", %{})

      {:error, _} ->
        put_flash(socket, :error, "Could not delete photos")
    end)
    |> close_modal()
    |> noreply()
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

  defp options(album) do
    select_options =
      [%{title: "All", id: "selected_all"}] ++
        if album && album.is_proofing do
          [%{title: "None", id: "selected_none"}]
        else
          [%{title: "Favorite", id: "selected_favorite"}, %{title: "None", id: "selected_none"}]
        end

    select_options
  end

  defp page_title(:index), do: "Photos"
  defp page_title(:edit), do: "Edit Photos"
  defp page_title(:upload), do: "New Photos"

  defp extract_album(album, album_return, other) do
    if album, do: Map.get(album, album_return), else: other
  end

  defp proofing_album_hash(album, socket) do
    album = Albums.set_album_hash(album)
    Routes.gallery_client_album_path(socket, :proofing_album, album.client_link_hash)
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

  defp add_cache(%{assigns: %{current_user: user, gallery: gallery}}, pid) do
    upload_data = PicselloWeb.UploaderCache.get(user.id)
    gallery_ids = upload_data |> Enum.map(fn {_, gallery_id, _} -> gallery_id end)

    if gallery.id not in gallery_ids do
      PicselloWeb.UploaderCache.put(user.id, [{pid, gallery.id, 0} | upload_data])
    end
  end

  defp album_actions(assigns) do
    assigns = assigns |> Enum.into(%{exclude_album_id: nil})

    ~H"""
    <%= for album <- @albums do %>
      <%= if @exclude_album_id != album.id && @exclude_album_id != "client_liked" do %>
        <li class={"relative py-1 hover:bg-blue-planning-100 hover:rounded-md #{get_class(album.name)}"}>
          <button class="album-actions" phx-click="move_to_album_popup" phx-value-album_id={album.id}>Move to <%= truncate(album.name) %></button>
          <div class="cursor-default tooltiptext">Move to <%= album.name %></div>
        </li>
      <% end %>
    <% end %>
    """
  end

  defp photo_loader(assigns) do
    ~H"""
    <%= for {_, index} <- Enum.with_index(@inprogress_photos) do%>
      <div id={"photo-loader-#{index}"} class="item h-[130px] photo-loader flex bg-gray-200">
        <div class="relative cursor-pointer item-content preview">
          <div class="galleryLoader">
            <img src={@url} class="relative" />
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp success_component_items() do
    %{
      "proofing" => {
        "Set Up Your Proofing Gallery",
        "Your proofing gallery is up and running! Your first proofing album lives within your gallery for this job."
      },
      "standard" => {
        "Gallery Created!",
        "Hooray! Your gallery has been created. You're now ready to upload photos."
      }
    }
  end
end
