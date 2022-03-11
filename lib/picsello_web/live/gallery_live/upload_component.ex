defmodule PicselloWeb.GalleryLive.UploadComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  import Picsello.Galleries.PhotoProcessing.GalleryUploadProgress, only: [progress_for_entry: 2]

  alias Picsello.Galleries
  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.PhotoProcessing.GalleryUploadProgress
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias Picsello.Galleries.Workers.PhotoStorage

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
  def mount(socket) do
    {:ok,
     socket
     |> assign(:upload_bucket, @bucket)
     |> assign(:toggle, "show")
     |> assign(:overall_progress, 0)
     |> assign(:estimate, "n/a")
     |> assign(:uploaded_files, 0)
     |> assign(:progress, %GalleryUploadProgress{})
     |> assign(:update_mode, "prepend")
     |> allow_upload(:photo, @upload_options)}
  end

  @impl true
  def handle_event("start", _params, %{assigns: %{gallery: gallery}} = socket) do
    gallery = Galleries.load_watermark_in_gallery(gallery)
    IO.puts("\n\n########## DEBUG ##########\n socket: #{inspect(socket, pretty: true)} \n########## DEBUG ##########\n\n")
    socket =
      Enum.reduce(socket.assigns.uploads.photo.entries, socket, fn
        %{valid?: false, ref: ref}, socket -> cancel_upload(socket, :photo, ref)
        _, socket -> socket
      end)

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
  def handle_event("close", _, socket) do
    send(self(), :close_upload_popup)

    socket |> noreply()
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

  def handle_progress(
        :photo,
        entry,
        %{assigns: %{gallery: gallery, uploaded_files: uploaded_files, progress: progress}} =
          socket
      ) do
    if entry.done? do
      {:ok, photo} = create_photo(gallery, entry)

      start_photo_processing(photo, gallery.watermark)

      socket
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

  defp create_photo(gallery, entry) do
    Galleries.create_photo(%{
      gallery_id: gallery.id,
      name: entry.client_name,
      original_url: Photo.original_path(entry.client_name, gallery.id, entry.uuid),
      position: (gallery.total_count || 0) + 100
    })
  end

  defp start_photo_processing(photo, watermark) do
    ProcessingManager.start(photo, watermark)
  end
end
