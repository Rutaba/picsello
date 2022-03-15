defmodule PicselloWeb.GalleryLive.Overview do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  import PicselloWeb.GalleryLive.Show, only: [presign_cover_entry: 2, handle_cover_progress: 3]

  alias Picsello.Galleries
  alias PicselloWeb.GalleryLive.Settings.CustomWatermarkComponent
  alias PicselloWeb.ConfirmationComponent
  alias Picsello.Galleries.CoverPhoto
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager

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
    {
      :ok,
      socket
      |> assign(:upload_bucket, @bucket)
      |> assign(:cover_photo_processing, false)
      |> allow_upload(:cover_photo, @upload_options)
      |> assign(:password_toggle, false)
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
      confirm_event: "delete_gallery",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete gallery?",
      subtitle:
        "Are you sure you wish to permanently delete #{gallery.name} gallery, and the #{gallery.total_count} photos it contains?"
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
end
