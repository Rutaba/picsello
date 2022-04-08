defmodule PicselloWeb.GalleryLive.Photos.Index do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  import PicselloWeb.LiveHelpers
  import PicselloWeb.GalleryLive.Shared

  alias Phoenix.PubSub
  alias Picsello.Repo
  alias Picsello.{Galleries, Albums, Messages}
  alias Picsello.Galleries.Workers.PositionNormalizer
  alias Picsello.Notifiers.ClientNotifier
  alias PicselloWeb.ConfirmationComponent
  alias PicselloWeb.GalleryLive.Photos.{PhotoPreview, PhotoView}
  alias PicselloWeb.GalleryLive.Settings.AddAlbumModal
  alias PicselloWeb.GalleryLive.Shared.GalleryMessageComponent

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
    album = Albums.get_album!(album_id) |> Repo.preload(:photo)

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
    |> open_modal(AddAlbumModal, %{gallery_id: gallery.id})
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
    |> open_modal(
      PicselloWeb.GalleryLive.EditAlbumThumbnail,
      %{album_id: album.id, gallery_id: gallery.id}
    )
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
    |> open_modal(PicselloWeb.GalleryLive.Albums.AlbumSettingsModal, %{
      gallery_id: gallery.id,
      album: album
    })
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
    Galleries.move_to_album(album_id, selected_photos)

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
            favorites_filter: toggle_state
          }
        } = socket
      ) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, !toggle_state)
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
    socket
    |> make_popup("delete_photo", "Delete this photo?", %{photo_id: id})
    |> noreply()
  end

  @impl true
  def handle_event("delete_selected_photos_popup", _, socket) do
    socket
    |> make_popup("delete_selected_photos", "Delete these photos?")
    |> noreply()
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
    photo_ids = Galleries.get_gallery_photo_ids(gallery.id, make_opts(socket, @per_page))

    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, true)
    |> assign(:selected_photos, photo_ids)
    |> push_event("select_mode", %{"mode" => "selected_favorite"})
    |> assign(:select_mode, "selected_favorite")
    |> assign_photos(@per_page)
    |> noreply
  end

  @impl true
  def handle_event(
        "selected_photos",
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
    |> GalleryMessageComponent.open(%{
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

  @impl true
  def handle_info({:photo_processed, _, photo}, socket) do
    photo_update =
      %{
        id: photo.id,
        url: display_photo(photo.watermarked_preview_url || photo.preview_url)
      }
      |> Jason.encode!()

    socket
    |> assign(:photo_updates, photo_update)
    |> noreply()
  end

  # def handle_info({:photo_click, _}, socket), do: noreply(socket)

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
  def handle_info({:save, %{title: title}}, socket) do
    socket
    |> close_modal()
    |> put_flash(:gallery_success, "#{title} successfully updated")
    |> assign_photos(@per_page)
    |> noreply
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
    Enum.each(selected_photos, fn photo_id ->
      Galleries.get_photo(photo_id)
      |> Galleries.delete_photo()
    end)

    {:ok, gallery} =
      Galleries.update_gallery(gallery, %{
        total_count: gallery.total_count - total(selected_photos)
      })

    socket
    |> assign(:gallery, gallery)
    |> assign(:selected_photos, [])
    |> close_modal()
    |> push_event("remove_items", %{"ids" => selected_photos})
    |> assign_photos(@per_page)
    |> noreply()
  end

  defp make_popup(socket, event, title, payload \\ %{}) do
    subtitle =
      case payload do
        %{photo_id: _} ->
          "Are you sure you wish to permanently delete this photo from #{socket.assigns.gallery.name} ?"

        _ ->
          "Are you sure you wish to permanently delete these photos from #{socket.assigns.gallery.name} ?"
      end

    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: event,
      class: "dialog-photographer",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: title,
      subtitle: subtitle,
      payload: payload
    })
  end

  defp move_to_album_success_message(selected_photos, album_id, gallery) do
    [album | _] =
      gallery.albums |> Enum.filter(fn %{id: id} -> id == String.to_integer(album_id) end)

    photos_count = total(selected_photos)
    "#{photos_count} photo#{is_plural(photos_count)} successfully moved to #{album.name}"
  end

  defp remove_from_album_success_message(selected_photos, album) do
    photos_count = total(selected_photos)
    "#{photos_count} photo#{is_plural(photos_count)} successfully removed from #{album.name}"
  end

  defp options(:select),
    do: [
      %{title: "All", id: "selected_all"},
      %{title: "Favorite", id: "selected_favorite"},
      %{title: "None", id: "selected_none"}
    ]

  defp is_plural(count) do
    if count > 1, do: "s"
  end

  defp page_title(:index), do: "Photos"
  defp page_title(:edit), do: "Edit Photos"
  defp page_title(:upload), do: "New Photos"

  defp total(list) when is_list(list), do: list |> length
  defp total(_), do: nil

  defp extract_album(album, album_retun, other) do
    if album, do: Map.get(album, album_retun), else: other
  end
end
