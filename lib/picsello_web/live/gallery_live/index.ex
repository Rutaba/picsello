defmodule PicselloWeb.GalleryLive.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  import PicselloWeb.GalleryLive.Show, only: [presign_cover_entry: 2, handle_cover_progress: 3]

  alias Picsello.Galleries
  alias PicselloWeb.GalleryLive.Settings.CustomWatermarkComponent
  alias PicselloWeb.GalleryLive.Shared.ConfirmationComponent
  alias Picsello.Galleries.CoverPhoto
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias Picsello.Messages
  alias Picsello.Notifiers.ClientNotifier
  alias PicselloWeb.GalleryLive.Photos.Upload
  alias PicselloWeb.ClientMessageComponent

  @upload_options [
    accept: ~w(.jpg .jpeg .png image/jpeg image/png),
    max_entries: 1,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &presign_cover_entry/2,
    progress: &handle_cover_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, datetime} = DateTime.now("UTC")

    {
      :ok,
      socket
      |> assign(:upload_bucket, @bucket)
      |> assign(:total_progress, 0)
      |> assign(:cover_photo_processing, false)
      |> allow_upload(:cover_photo, @upload_options)
      |> assign(:password_toggle, false)
      |> assign(:date, datetime)
    }
  end

  @impl true
  def handle_event("start", _params, socket) do
    socket.assigns.uploads.cover_photo
    |> case do
      %{valid?: false, ref: ref} -> {:noreply, cancel_upload(socket, :cover_photo, ref)}
      _ -> {:noreply, socket}
    end
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
        "open_gallery_deletion_popup",
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
      close_class: "delete_btn",
      confirm_event: "delete_gallery",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete Gallery?",
      gallery_name: gallery.name,
      gallery_count: gallery.total_count
    })
    |> noreply()
  end

  def handle_info({:cover_photo_processed, _, _}, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.get_gallery!(gallery.id))
    |> assign(:cover_photo_processing, false)
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "delete_gallery"},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    case Galleries.delete_gallery(gallery) do
      {:ok, _gallery} ->
        socket
        |> push_redirect(to: Routes.job_path(socket, :jobs, gallery.job_id))
        |> put_flash(:success, "The gallery has been deleted.")
        |> noreply()

      _any ->
        socket
        |> put_flash(:error, "Could not delete gallery.")
        |> close_modal()
        |> noreply()
    end
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

  def handle_cover_progress(:cover_photo, entry, %{assigns: %{gallery: gallery}} = socket) do
    if entry.done? do
      CoverPhoto.original_path(gallery.id, entry.uuid)
      |> ProcessingManager.process_cover_photo()

      socket
      |> assign(:cover_photo_processing, true)
      |> noreply()
    else
      socket
      |> noreply
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    socket
    |> assign(:gallery, Galleries.load_watermark_in_gallery(gallery))
    |> noreply()
  end

  @impl true
  def handle_event("open_watermark_popup", _, socket) do
    send(self(), :open_modal)
    socket |> noreply()
  end

  def handle_event("share_link", params, socket) do
    PicselloWeb.GalleryLive.Show.handle_event("client-link", params, socket)
  end

  @impl true
  def handle_event("open_watermark_deletion_popup", _, socket) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_watermark",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete watermark?",
      subtitle: "Are you sure you wish to permanently delete your
        custom watermark? You can always add another
        one later."
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
  def handle_info(:open_modal, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> open_modal(CustomWatermarkComponent, %{gallery: gallery})
    |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "delete_watermark"}, %{assigns: %{gallery: gallery}} = socket) do
    Galleries.delete_gallery_watermark(gallery.watermark)
    send(self(), :clear_watermarks)

    socket
    |> close_modal()
    |> preload_watermark()
    |> noreply()
  end

  @impl true
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
  end

  @impl true
  def handle_info(:close_watermark_popup, socket) do
    socket |> close_modal() |> noreply()
  end

  @impl true
  def handle_info(:preload_watermark, socket) do
    socket
    |> preload_watermark()
    |> noreply()
  end

  @impl true
  def handle_info({:photo_processed, _}, socket), do: noreply(socket)

  @impl true
  def handle_info(:clear_watermarks, %{assigns: %{gallery: gallery}} = socket) do
    Galleries.clear_watermarks(gallery.id)
    noreply(socket)
  end

  @impl true
  def handle_info(:expiration_saved, socket) do
    socket
    |> put_flash(:success, "The expiration date has been saved.")
    |> noreply()
  end

  defp preload_watermark(%{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.load_watermark_in_gallery(gallery))
  end

  defp never_date() do
    {:ok, date} = DateTime.new(~D[3022-02-01], ~T[12:00:00], "Etc/UTC")
    date
  end
end
