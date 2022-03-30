defmodule PicselloWeb.GalleryLive.Album do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  import PicselloWeb.LiveHelpers
  import Picsello.Galleries.PhotoProcessing.GalleryUploadProgress, only: [progress_for_entry: 2]

  alias Phoenix.PubSub
  alias Picsello.Galleries
  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.Album
  alias Picsello.Galleries.CoverPhoto
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Picsello.Galleries.Workers.PositionNormalizer
  alias Picsello.Messages
  alias Picsello.Notifiers.ClientNotifier
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias PicselloWeb.GalleryLive.UploadComponent
  alias PicselloWeb.GalleryLive.Shared.ConfirmationComponent
  alias PicselloWeb.GalleryLive.Photos.PhotoComponent
  alias Picsello.Galleries.PhotoProcessing.GalleryUploadProgress
  alias PicselloWeb.GalleryLive.ViewPhoto
  alias Picsello.Repo
  alias PicselloWeb.GalleryLive.Shared.ClientMessageComponent

  @per_page 12
  @upload_options [
    accept: ~w(.jpg .jpeg .png image/jpeg image/png),
    max_entries: 1500,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &__MODULE__.presign_entry/2,
    progress: &__MODULE__.handle_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:upload_bucket, @bucket)
      |> assign(:overall_progress, 0)
      |> assign(:estimate, "n/a")
      |> assign(:upload_toast, "hidden")
      |> assign(:error_toast, "hidden")
      |> assign(:uploaded_files, 0)
      |> assign(:progress, %GalleryUploadProgress{})
      |> assign(:photo_updates, "false")
      |> assign(:selected_all, "false")
      |> assign(:selected_favorite, "false")
      |> assign(:show_tick, "w-6 h-5 mr-3")
      |> assign(:select_mode, "selected_none")
      |> assign(:update_mode, "append")
      |> allow_upload(:photo, @upload_options)
      |> assign(:actions_dropdown_show, false)
      |> assign(:selected_photos, [])
    }
  end

  @impl true
  def handle_params(%{"id" => id, "album_id" => album_id}, _, socket) do
    gallery = Galleries.get_gallery!(id) |> Repo.preload(:albums)

    album = Repo.get!(Picsello.Galleries.Album, album_id) |> Repo.preload(:photo)

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery.id}")
    end

    a =
      socket
      |> assign(
        favorites_count: Galleries.gallery_favorites_count(gallery),
        favorites_filter: false,
        gallery: gallery,
        album: album,
        page: 0,
        page_title: page_title(socket.assigns.live_action),
        products: Galleries.products(gallery)
      )
      |> assign_photos()
      |> then(fn
        %{
          assigns: %{
            live_action: :upload
          }
        } = socket ->
          send(self(), :open_modal)
          socket

        socket ->
          socket
      end)

    a |> noreply()
  end

  # upload start
  @impl true
  def handle_event("start", _params, %{assigns: %{gallery: %{id: id}}} = socket) do
    IO.inspect("reached 2")
    gallery = Galleries.get_gallery!(id)
    gallery = Galleries.load_watermark_in_gallery(gallery)

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery.id}")
    end

    #  socket =
    #    Enum.reduce(socket.assigns.uploads.photo.entries, socket, fn
    #      %{valid?: false, ref: ref}, socket -> cancel_upload(socket, :photo, ref)
    #      _, socket -> socket
    #    end)

    socket
    |> assign(
      :progress,
      Enum.reduce(
        socket.assigns.uploads.photo.entries,
        socket.assigns.progress,
        fn entry, progress -> GalleryUploadProgress.add_entry(progress, entry) end
      )
    )
    |> assign(:update_mode, "prepend")
    |> assign(:gallery, gallery)
    |> noreply()
  end

  @impl true
  def handle_event(
        "select_photos",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
      socket
      |> push_redirect(to: Routes.gallery_albums_path(socket, :albums, gallery))
      |> noreply()
  end




  @impl true
  def handle_event("close", _, socket) do
    # send(self(), :close_upload_popup)

    socket |> noreply()
  end

  @impl true
  def handle_event(
        "edit_album_thumbnail_selected",
        _,
        %{
          assigns: %{
            gallery: gallery,
            album: album
          }
        } = socket
      ) do
    socket
    |> assign(:selected_item, "edit_album_thumbnail")
    |> push_redirect(
      to: Routes.gallery_edit_album_thumbnail_path(socket, :show, gallery.id, album.id)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_album_settings_selected",
        _,
        %{
          assigns: %{
            gallery: gallery,
            album: album
          }
        } = socket
      ) do
    socket
    |> assign(:selected_item, "go_to_album_settings")
    |> open_modal(PicselloWeb.GalleryLive.Albums.AlbumSettingsModal, %{
      gallery_id: gallery.id,
      album: album
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "cancel-upload",
        %{"ref" => ref},
        %{assigns: %{uploads: %{photo: %{entries: entries}}}} = socket
      ) do
    entry =
      entries
      |> Enum.find(&(&1.ref == ref))

    socket
    |> assign(:update_mode, "replace")
    |> assign(:progress, GalleryUploadProgress.remove_entry(socket.assigns.progress, entry))
    |> cancel_upload(:photo, ref)
    |> noreply()
  end

  @impl true
  def handle_event("upload_toast", _, socket) do
    socket
    |> assign(:upload_toast, "hidden")
    |> noreply()
  end

  @impl true
  def handle_event("error_toast", _, socket) do
    socket
    |> assign(:error_toast, "hidden")
    |> noreply()
  end

  def handle_progress(
        :photo,
        entry,
        %{
          assigns: %{
            gallery: gallery,
            uploaded_files: uploaded_files,
            progress: progress,
            album: album
          }
        } = socket
      ) do
    if entry.done? do
      {:ok, photo} = create_photo_with_album(gallery, entry, album.id)
      IO.inspect("reached 3")

      start_photo_processing(photo, gallery.watermark)

      socket
      |> assign(:upload_toast, "")
      |> assign(uploaded_files: uploaded_files + 1)
      |> assign(
        progress:
          progress
          |> GalleryUploadProgress.complete_upload(entry)
      )
      |> assign_overall_progress()
      |> noreply()
    else
      socket
      |> assign(
        progress:
          progress
          |> GalleryUploadProgress.track_progress(entry)
      )
      |> assign_overall_progress()
      |> noreply()
    end
  end

  def presign_entry(entry, %{assigns: %{gallery: gallery}} = socket) do
    key = Photo.original_path(entry.client_name, gallery.id, entry.uuid)

    sign_opts = [
      expires_in: 144_000,
      bucket: socket.assigns.upload_bucket,
      key: key,
      fields: %{
        "content-type" => entry.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, 104_857_600]]
    ]

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  defp total(list) when is_list(list), do: list |> length
  defp total(_), do: nil

  defp assign_overall_progress(%{assigns: %{progress: progress}} = socket) do
    total_progress = GalleryUploadProgress.total_progress(progress)
    estimate = GalleryUploadProgress.estimate_remaining(progress, DateTime.utc_now())

    if total_progress == 100 do
      send(self(), {:photo_upload_completed, socket.assigns.uploaded_files})
    end

    socket
    |> assign(:overall_progress, total_progress)
    |> assign(:estimate, estimate)
  end

  defp create_photo_with_album(gallery, entry, album_id) do
    Galleries.create_photo(%{
      gallery_id: gallery.id,
      name: entry.client_name,
      album_id: album_id,
      original_url: Photo.original_path(entry.client_name, gallery.id, entry.uuid),
      position: (gallery.total_count || 0) + 100
    })
  end

  defp start_photo_processing(photo, watermark) do
    ProcessingManager.start(photo, watermark)
  end

  # upload end

  @impl true
  def handle_event("upload-failed", _, socket) do
    socket
    |> open_modal(
      UploadComponent,
      socket.assigns
    )
    |> noreply
  end

  @impl true
  def handle_event("click", _, socket) do
    socket
    |> noreply()
  end

  @impl true
  def handle_event(
        "view",
        %{"preview_photo_id" => photo_id},
        %{
          assigns: %{
            gallery: gallery,
            favorites_filter: favorites_filter
          }
        } = socket
      ) do
    photo_ids =
      Galleries.get_photo_ids(gallery_id: gallery.id, favorites_filter: favorites_filter)

    socket
    |> open_modal(
      ViewPhoto,
      %{
        gallery: gallery,
        photo_id: photo_id,
        photo_ids:
          CLL.init(photo_ids)
          |> CLL.next(Enum.find_index(photo_ids, &(&1 == to_integer(photo_id))) || 0)
      }
    )
    |> noreply
  end

  @impl true
  def handle_event(
        "move_to_album",
        %{"album" => album_id} = _params,
        %{
          assigns: %{
            album: album,
            gallery: gallery,
            selected_photos: selected_photos
          }
        } = socket
      ) do
    Galleries.update_photos_album_id(selected_photos, album_id)

    socket
    |> push_redirect(to: Routes.gallery_album_path(socket, :show, gallery.id, album.id))
    |> put_flash(:success, "Photo moved successfully")
    |> noreply()
  end

  @impl true
  def handle_event(
        "remove_from_album",
        _,
        %{
          assigns: %{
            album: album,
            gallery: gallery,
            selected_photos: selected_photos
          }
        } = socket
      ) do
    Galleries.remove_photos_from_album(selected_photos)

    socket
    |> push_redirect(to: Routes.gallery_album_path(socket, :show, gallery.id, album.id))
    |> put_flash(:success, "Photo removed successfully")
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete_photos",
        _,
        %{
          assigns: %{
            album: album,
            gallery: gallery,
            selected_photos: selected_photos
          }
        } = socket
      ) do
    Galleries.delete_photos(selected_photos)

    socket
    |> push_redirect(to: Routes.gallery_album_path(socket, :show, gallery.id, album.id))
    |> put_flash(:success, "Photo deleted successfully")
    |> noreply()
  end

  @impl true
  def handle_event("open_upload_popup", _, socket) do
    send(self(), :open_modal)

    socket
    |> noreply()
  end

  @impl true
  def handle_event(
        "open_album_remove_photo_popup",
        %{"photo" => photo_id} = _params,
        %{
          assigns: %{
            album: album
          }
        } = socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      close_class: "delete_btn",
      confirm_event: "remove_from_album",
      confirm_label: "Yes, remove",
      icon: "warning-orange",
      title: "Remove from album?",
      subtitle: "Are you sure you wish to remove this photo from #{album.name}?",
      payload: %{
        photo_id: photo_id
      }
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "open_set_thumbnail_popup",
        %{"id" => photo_id} = _params,
        %{
          assigns: %{
            album: album,
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      close_class: "delete_btn",
      confirm_event: "set_album_thumbnail",
      confirm_label: "Yes, set as thumbnail",
      icon: "warning-orange",
      title: "Set as thumbnail?",
      subtitle: "Are you sure you wish to set this photo as a thumbnail for #{album.name} ?",
      album_name: album.name,
      gallery_count: gallery.total_count,
      payload: %{
        photo_id: photo_id
      }
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "actions_dropdown",
        _,
        %{
          assigns: %{
            actions_dropdown_show: actions_dropdown_show
          }
        } = socket
      ) do
    actions_dropdown_updated =
      case actions_dropdown_show do
        false -> true
        true -> false
      end

    socket
    |> assign(:actions_dropdown_show, actions_dropdown_updated)
    |> noreply()
  end

  @impl true
  def handle_event(
        "preview_gallery",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    socket
    |> push_redirect(to: Routes.gallery_client_show_path(socket, :show, hash))
    |> noreply()
  end

  @impl true
  def handle_event(
        "gallery_settings",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_settings_path(socket, :settings, gallery))
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
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle_favorites",
        _,
        %{
          assigns: %{
            favorites_filter: toggle_state
          }
        } = socket
      ) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, !toggle_state)
    |> assign_photos()
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
  def handle_event(
        "delete_cover_photo_popup",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_cover_photo",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete this photo?",
      subtitle: "Are you sure you wish to permanently delete this photo from #{gallery.name} ?"
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete_photo_popup",
        %{"id" => id},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_photo",
      classes: "dialog-photographer",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete this photo?",
      subtitle: "Are you sure you wish to permanently delete this photo from #{gallery.name} ?",
      payload: %{
        photo_id: id
      }
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "selected_all",
        _,
        %{
          assigns: %{
            selected_all: selected_all,
            gallery: gallery,
            favorites_filter: favorites_filter
          }
        } = socket
      ) do
    photo_ids =
      Galleries.get_photo_ids(gallery_id: gallery.id, favorites_filter: favorites_filter)

    socket
    |> assign(:selected_all, "photo-border")
    |> assign(:selected_photos, photo_ids)
    |> assign(:select_mode, "selected_all")
    |> noreply
  end

  @impl true
  def handle_event("selected_none", _, %{assigns: %{selected_all: selected_all}} = socket) do
    socket
    |> then(fn
      %{
        assigns: %{
          favorites_filter: true
        }
      } = socket ->
        socket
        |> assign(:page, 0)
        |> assign(:favorites_filter, false)
        |> assign(:select_mode, "selected_none")
        |> assign_photos()

      socket ->
        socket
    end)
    |> assign(:selected_all, "false")
    |> assign(:selected_photos, [])
    |> noreply
  end

  @impl true
  def handle_event(
        "selected_favorite",
        _,
        %{
          assigns: %{
            selected_favorite: selected_favorite,
            gallery: gallery
          }
        } = socket
      ) do
    photo_ids = Galleries.get_photo_ids(gallery_id: gallery.id, favorites_filter: true)

    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:selected_all, "photo-border")
    |> assign(:favorites_filter, true)
    |> assign(:selected_photos, photo_ids)
    |> assign(:select_mode, "selected_favorite")
    |> assign_photos()
    |> noreply
  end

  @impl true
  def handle_event(
        "client-link",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    gallery = Picsello.Repo.preload(gallery, job: :client)

    link = Routes.gallery_client_show_url(socket, :show, hash)
    client_name = gallery.job.client.name

    subject = "#{gallery.name} photos"

    html = """
    <p>Hi #{client_name},</p>
    <p>Your gallery is ready to view! You can view the gallery here: <a href="#{link}">#{link}</a></p>
    <p>Your photos are password-protected, so you'll also need to use this password to get in: <b>#{gallery.password}</b></p>
    <p>Happy viewing!</p>
    """

    text = """
    Hi #{client_name},

    Your gallery is ready to view! You can view the gallery here: #{link}

    Your photos are password-protected, so you'll also need to use this password to get in: #{gallery.password}

    Happy viewing!
    """

    socket
    |> assign(:job, gallery.job)
    |> assign(:gallery, gallery)
    |> ClientMessageComponent.open(%{
      body_html: html,
      body_text: text,
      subject: subject,
      modal_title: "Share gallery"
    })
    |> noreply()
  end

  def handle_info(
        {:message_composed, message_changeset},
        %{
          assigns: %{
            job: job
          }
        } = socket
      ) do
    with {:ok, message} <- Messages.add_message_to_job(message_changeset, job),
         {:ok, _email} <- ClientNotifier.deliver_email(message, job.client.email) do
      socket
      |> close_modal()
      |> noreply()
    else
      _error ->
        socket
        |> put_flash(:error, "Something went wrong")
        |> close_modal()
        |> noreply()
    end
  end

  def handle_info(
        {:confirm_event, "remove_from_album", %{photo_id: photo_id}},
        %{
          assigns: %{
            album: album,
            gallery: gallery
          }
        } = socket
      ) do
    photo_id = String.split(photo_id, ",")
    Galleries.remove_photos_from_album(photo_id)

    socket
    |> close_modal()
    |> push_redirect(to: Routes.gallery_album_path(socket, :show, gallery.id, album.id))
    |> put_flash(:success, "Photo removed successfully")
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

    photo = Galleries.get_photo(photo_id)
    album
    |> Album.update_changeset(%{thumbnail_url:  photo.preview_url})
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

  @impl true
  def handle_info({:photo_processed, _, photo}, %{assigns: %{gallery: gallery}} = socket) do
    photo_update =
      %{
        id: photo.id,
        url: display_photo(photo.watermarked_preview_url || photo.preview_url)
      }
      |> Jason.encode!()

    IO.inspect(photo_update)

    socket
    # |> assign(:gallery, Galleries.get_gallery!(gallery.id))
    |> assign(:photo_updates, photo_update)
    |> noreply()
  end

  def handle_info({:cover_photo_processed, _, _}, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.get_gallery!(gallery.id))
    |> assign(:cover_photo_processing, false)
    |> noreply()
  end

  def handle_info({:photo_click, _}, socket), do: noreply(socket)

  def handle_info(
        {:selected_photos, id},
        %{assigns: %{selected_photos: selected_photos}} = socket
      ) do
    selected_photos =
      if Enum.member?(selected_photos, id) do
        List.delete(selected_photos, id)
      else
        [id | selected_photos]
      end

    socket
    |> assign(:selected_photos, selected_photos)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_cover_photo"},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> assign(:gallery, Galleries.delete_gallery_cover_photo(gallery))
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_photo", %{photo_id: id}},
        %{
          assigns: %{
            gallery: gallery,
            selected_photos: selected_photos
          }
        } = socket
      ) do
    Galleries.get_photo(id)
    |> Galleries.delete_photo()

    {:ok, gallery} = Galleries.update_gallery(gallery, %{total_count: gallery.total_count - 1})

    send_update(PhotoComponent, id: String.to_integer(id), is_removed: true)

    socket
    |> assign(:gallery, gallery)
    |> assign(:selected_photos, List.delete(selected_photos, String.to_integer(id)))
    |> close_modal()
    |> push_event("remove_item", %{"id" => id})
    |> noreply()
  end

  def handle_info(
        :open_modal,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> open_modal(UploadComponent, %{gallery: gallery})
    |> noreply()
  end

  def handle_info(:close_upload_popup, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:photo_upload_completed, _count},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    IO.inspect(gallery)
    Galleries.update_gallery_photo_count(gallery.id)

    Galleries.normalize_gallery_photo_positions(gallery.id)
    #    gallery = Galleries.get_gallery!(gallery.id)
    # IO.inspect(gallery)
    socket
    #    |> push_redirect(to: Routes.gallery_photos_path(socket, :show, gallery.id))
    |> assign_photos()
    |> noreply()
  end

  # def handle_cover_progress(:cover_photo, entry, %{assigns: %{gallery: gallery}} = socket) do
  #   if entry.done? do
  #     CoverPhoto.original_path(gallery.id, entry.uuid)
  #     |> ProcessingManager.process_cover_photo()

  #     socket
  #     |> assign(:cover_photo_processing, true)
  #     |> noreply()
  #   else
  #     socket
  #     |> noreply
  #   end
  # end

  def presign_cover_entry(entry, %{assigns: %{gallery: gallery}} = socket) do
    key = CoverPhoto.original_path(gallery.id, entry.uuid)

    sign_opts = [
      expires_in: 600,
      bucket: socket.assigns.upload_bucket,
      key: key,
      fields: %{
        "content-type" => entry.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, 104_857_600]]
    ]

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{
               id: id
             },
             album: album,
             page: page,
             favorites_filter: filter
           }
         } = socket,
         per_page \\ @per_page
       ) do
    opts = [only_favorites: filter, offset: per_page * page]
    photos = Galleries.get_album_photos(id, per_page + 1, page, album.id, opts)

    socket
    |> assign(
      :photos,
      photos
      |> Enum.take(per_page)
    )
    |> assign(
      :has_more_photos,
      photos
      |> length > per_page
    )
  end

  # duplicate functions, already exist in uploads
  def presign_entry(entry, %{assigns: %{gallery: gallery}} = socket) do
    key = Photo.original_path(entry.client_name, gallery.id, entry.uuid)

    sign_opts = [
      expires_in: 144_000,
      bucket: socket.assigns.upload_bucket,
      key: key,
      fields: %{
        "content-type" => entry.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, 104_857_600]]
    ]

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"
  defp page_title(:upload), do: "New Gallery"

  def product_preview_url(%{
        preview_photo: %{
          preview_url: url
        }
      }),
      do: url

  def product_preview_url(_), do: nil
end
