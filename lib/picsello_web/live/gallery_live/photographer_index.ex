defmodule PicselloWeb.GalleryLive.PhotographerIndex do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_photographer"]
  import PicselloWeb.LiveHelpers
  import PicselloWeb.GalleryLive.Shared

  alias Phoenix.PubSub
  alias Picsello.{Galleries, Messages, Notifiers.ClientNotifier}

  alias PicselloWeb.GalleryLive.{
    Settings.CustomWatermarkComponent,
    Shared.ConfirmationComponent,
    Photos.Upload
  }

  alias Galleries.{
    CoverPhoto,
    Workers.PhotoStorage,
    PhotoProcessing.ProcessingManager,
    PhotoProcessing.Waiter
  }

  @upload_options [
    accept: ~w(.jpg .jpeg .png image/jpeg image/png),
    max_entries: 1,
    max_file_size: String.to_integer(Application.compile_env(:picsello, :photo_max_file_size)),
    auto_upload: true,
    external: &__MODULE__.presign_cover_entry/2,
    progress: &__MODULE__.handle_cover_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:upload_bucket, @bucket)
    |> assign(:total_progress, 0)
    |> assign(:photos_error_count, 0)
    |> assign(:cover_photo_processing, false)
    |> allow_upload(:cover_photo, @upload_options)
    |> assign(:password_toggle, false)
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery =
      Galleries.get_gallery!(id)
      |> Galleries.load_watermark_in_gallery()

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery.id}")
    end

    prepare_gallery(gallery)

    socket
    |> assign(:gallery, gallery)
    |> noreply()
  end

  @impl true
  def handle_event("start", _params, socket) do
    socket.assigns.uploads.cover_photo
    |> case do
      %{valid?: false, ref: ref} ->
        {:noreply, cancel_upload(socket, :cover_photo, ref)}

      _ ->
        socket |> noreply()
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
      class: "dialog-photographer",
      title: "Delete this photo?",
      subtitle: "Are you sure you wish to permanently delete this photo from #{gallery.name} ?"
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete_gallery_popup",
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
      class: "dialog-photographer",
      icon: "warning-orange",
      title: "Delete Gallery?",
      gallery_name: gallery.name,
      gallery_count: gallery.total_count
    })
    |> noreply()
  end

  @impl true
  def handle_event("delete_watermark_popup", _, socket) do
    opts = [
      event: "delete_watermark",
      title: "Delete watermark?",
      subtitle: "Are you sure you wish to permanently delete your
      custom watermark? You can always add another
      one later."
    ]

    make_popup(socket, opts)
  end

  @impl true
  def handle_event("client-link", _, socket) do
    share_gallery(socket)
  end

  @impl true
  def handle_event("watermark_popup", _, socket) do
    send(self(), :open_modal)
    socket |> noreply()
  end

  def handle_cover_progress(:cover_photo, entry, %{assigns: %{gallery: gallery}} = socket) do
    if entry.done? do
      CoverPhoto.original_path(gallery.id, entry.uuid)
      |> ProcessingManager.process_cover_photo()
    end

    socket
    |> assign(:cover_photo_processing, true)
    |> noreply
  end

  def handle_info(
        {:message_composed, message_changeset},
        %{
          assigns: %{
            job: job,
            gallery: gallery
          }
        } = socket
      ) do
    serialized_message =
      message_changeset
      |> :erlang.term_to_binary()
      |> Base.encode64()

    %{id: oban_job_id} =
      %{message: serialized_message, email: job.client.email, job_id: job.id}
      |> Picsello.Workers.ScheduleEmail.new(schedule_in: 900)
      |> Oban.insert!()

    Waiter.postpone(gallery.id, fn ->
      Oban.cancel_job(oban_job_id)

      {:ok, message} = Messages.add_message_to_job(message_changeset, job)
      ClientNotifier.deliver_email(message, job.client.email)
    end)

    socket
    |> close_modal()
    |> put_flash(:success, "Gallery shared!")
    |> noreply()
  end

  @impl true
  def handle_info(:open_modal, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> open_modal(CustomWatermarkComponent, %{gallery: gallery})
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_watermark", _},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    Galleries.delete_gallery_watermark(gallery.watermark)
    send(self(), :clear_watermarks)

    socket
    |> close_modal()
    |> preload_watermark()
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
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
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
  def handle_info(:clear_watermarks, %{assigns: %{gallery: gallery}} = socket) do
    Galleries.clear_watermarks(gallery.id)
    noreply(socket)
  end

  @impl true
  def handle_info(:expiration_saved, %{assigns: %{gallery: gallery}} = socket) do
    gallery = Galleries.get_gallery!(gallery.id) |> Galleries.load_watermark_in_gallery()

    socket
    |> assign(:gallery, gallery)
    |> put_flash(:success, "The expiration date has been successfully updated")
    |> noreply()
  end

  def handle_info({:cover_photo_processed, _, _}, %{assigns: %{gallery: gallery}} = socket) do
    gallery = Galleries.get_gallery!(gallery.id) |> Galleries.load_watermark_in_gallery()

    socket
    |> assign(:gallery, gallery)
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
        |> put_flash(:success, "The gallery has been deleted")
        |> noreply()

      _any ->
        socket
        |> put_flash(:error, "Could not delete gallery")
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

  @impl true
  def handle_info({:update_name, %{gallery: gallery}}, socket) do
    gallery = gallery |> Galleries.load_watermark_in_gallery()

    socket
    |> assign(:gallery, gallery)
    |> close_modal()
    |> noreply()
  end

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
      conditions: [["content-length-range", 0, String.to_integer(Application.get_env(:picsello, :photo_max_file_size))]]
    ]

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  defp preload_watermark(%{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.load_watermark_in_gallery(gallery))
  end

  defp remove_watermark_button(assigns) do
    ~H"""
    <button type="button" title="remove watermark" phx-click="delete_watermark_popup" class="pl-14">
      <.icon name="remove-icon" class="w-3.5 h-3.5 ml-1 text-base-250"/>
    </button>
    """
  end
end
