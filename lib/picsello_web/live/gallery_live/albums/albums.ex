defmodule PicselloWeb.GalleryLive.Albums do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries.Album
  alias Picsello.Galleries
  alias Picsello.Repo
  alias Picsello.Messages
  alias Picsello.Notifiers.ClientNotifier
  alias PicselloWeb.GalleryLive.Shared.ConfirmationComponent
  alias PicselloWeb.GalleryLive.Photos.Upload
  alias PicselloWeb.ClientMessageComponent

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:total_progress, 0)
      |> assign(:selected_item, nil)
    }
  end

  @impl true
  def handle_params(%{"id" => gallery_id}, _uri, socket) do
    gallery = Galleries.get_gallery!(gallery_id) |> Repo.preload(:albums)

    socket
    |> assign(:gallery_id, gallery_id)
    |> assign(:gallery, gallery)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open_albums_popup",
        %{},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> open_modal(PicselloWeb.GalleryLive.Settings.AddAlbumModal, %{gallery_id: gallery_id})
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
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_album",
      classes: "dialog-photographer",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete this album?",
      subtitle: "Are you sure you wish to permanently delete this album from #{gallery.name} ?",
      payload: %{
        album_id: id
      }
    })
    |> noreply()
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
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_unsorted_photos",
      classes: "dialog-photographer",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete this album?",
      subtitle: "Are you sure you wish to permanently delete this album from #{gallery.name} ?",
      payload: %{}
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "open_unsorted_photos",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery))
    |> noreply()
  end

  @impl true
  def handle_event(
        "clear_selected",
        %{},
        socket
      ) do
    socket
    |> assign(:selected_item, nil)
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_album_selected",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> assign(:selected_item, "go_to_album")
    |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery_id, album_id))
    |> noreply()
  end

  @impl true
  def handle_event(
        "share_album_selected",
        %{},
        %{
          assigns: %{}
        } = socket
      ) do
    socket
    |> assign(:selected_item, "share_album")
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit_album_thumbnail_selected",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> open_modal(
      PicselloWeb.GalleryLive.EditAlbumThumbnail,
      %{album_id: album_id, gallery_id: gallery_id}
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_album_settings_selected",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    album = Repo.get!(Album, album_id)

    socket
    |> assign(:selected_item, "go_to_album_settings")
    |> open_modal(PicselloWeb.GalleryLive.Albums.AlbumSettingsModal, %{
      gallery_id: gallery_id,
      album: album
    })
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
    <p>Your photos are password-protected, so you’ll also need to use this password to get in: <b>#{gallery.password}</b></p>
    <p>Happy viewing!</p>
    """

    text = """
    Hi #{client_name},

    Your gallery is ready to view! You can view the gallery here: #{link}

    Your photos are password-protected, so you’ll also need to use this password to get in: #{gallery.password}

    Happy viewing!
    """

    socket
    |> assign(:job, gallery.job)
    |> assign(:gallery, gallery)
    |> ClientMessageComponent.open(%{
      body_html: html,
      body_text: text,
      subject: subject,
      modal_title: "Share gallery",
      is_client_gallery: false
    })
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "delete_album", %{album_id: id}},
        socket
      ) do
    album = Repo.get!(Picsello.Galleries.Album, id) |> Repo.preload(:photo)

    case Galleries.delete_album(album) do
      {:ok, _album} ->
        socket
        |> put_flash(:gallery_success, "Album deleted successfully")
        |> close_modal()
        |> noreply()

      _any ->
        socket
        |> put_flash(:error, "Could not delete album.")
        |> close_modal()
        |> noreply()
    end
  end

  def handle_info(
        {:confirm_event, "delete_unsorted_photos", %{}},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    Galleries.delete_unsorted_photos(gallery.id)

    socket
    |> push_redirect(to: Routes.gallery_albums_path(socket, :albums, gallery))
    |> put_flash(:success, "The album has been deleted.")
    |> noreply()
  end

  @impl true
  def handle_info({:save, %{title: title}}, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> close_modal()
    |> push_redirect(to: Routes.gallery_albums_path(socket, :albums, gallery))
    |> put_flash(:gallery_success, "#{title} successfully updated")
    |> noreply
  end

  @impl true
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
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
end
