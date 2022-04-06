defmodule PicselloWeb.GalleryLive.Photos.Upload do
  @moduledoc false
  use PicselloWeb, :live_view

  import Picsello.Galleries.PhotoProcessing.GalleryUploadProgress, only: [progress_for_entry: 2]
  alias Phoenix.LiveView.{Upload, UploadConfig, UploadEntry}

  alias Phoenix.LiveView.{Upload, UploadConfig, UploadEntry}

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
  def mount(_params, %{"gallery" => gallery} = session, socket) do
    {:ok,
     socket
     |> put_flash(:gallery_success, "upload_success_message")
     |> assign(:upload_bucket, @bucket)
     |> assign(:view, Map.get(session, "view", false))
     |> assign(:album_id, Map.get(session, "album_id", nil))
     |> assign(:gallery, gallery)
     |> assign(:toggle, "show")
     |> assign(:overall_progress, 0)
     |> assign(:uploaded_files, 0)
     |> assign(:estimate, "n/a")
     |> assign(:progress, %GalleryUploadProgress{})
     |> assign(:update_mode, "append")
     |> allow_upload(:photo, @upload_options), layout: false}
  end

  @impl true
  def handle_event("start", _params, %{assigns: %{gallery: gallery}} = socket) do
    gallery = Galleries.load_watermark_in_gallery(gallery)
    entries = socket.assigns.uploads.photo.entries

    socket =
      Enum.reduce(entries, socket, fn
        %{valid?: false, ref: ref}, socket -> cancel_upload(socket, :photo, ref)
        _, socket -> socket
      end)

    socket
    |> assign(
      :progress,
      Enum.reduce(
        entries,
        socket.assigns.progress,
        fn entry, progress -> GalleryUploadProgress.add_entry(progress, entry) end
      )
    )
    |> assign(:entries, entries)
    |> assign(:update_mode, "append")
    |> assign(:gallery, gallery)
    |> noreply()
  end

  @impl true
  def handle_event("resume_upload", %{"ref" => ref}, socket) do
    upload_config = Map.fetch!(socket.assigns[:uploads] || %{}, :photo)
    %UploadEntry{} = entry = UploadConfig.get_entry_by_ref(upload_config, ref)
    entry = %UploadEntry{entry | preflighted?: false}

    photo = %UploadConfig{
      upload_config
      | entries: [entry],
        errors: []
    }

    photo1 = %UploadConfig{
      upload_config
      | entries: [],
        errors: []
    }

    uploads = put_in(socket.assigns.uploads, [:photo], photo)
    uploads1 = put_in(socket.assigns.uploads, [:photo], photo1)
    socket = assign(socket, :uploads, uploads)

    socket =
      assign(socket, :progress, %Picsello.Galleries.PhotoProcessing.GalleryUploadProgress{
        entries: %{},
        photo_entries: %{},
        since: nil
      })

    socket = assign(socket, :__changed__, %{uploads: uploads1})

    IO.puts(
      "\n\n########## DEBUG ##########\n uploads: #{inspect(uploads, pretty: true)} \n########## DEBUG ##########\n\n"
    )

    case uploaded_entries(socket, :photo) do
      {[_ | _] = completed, []} ->
        # all entries are completed
        IO.puts(
          "\n\n########## DEBUG ##########\n completed: #{inspect(completed, pretty: true)} \n########## DEBUG ##########\n\n"
        )

      {[], [_ | _] = in_progress} ->
        # all entries are still in progress
        IO.puts(
          "\n\n########## DEBUG ##########\n in_progress: #{inspect(in_progress, pretty: true)} \n########## DEBUG ##########\n\n"
        )
    end

    # {:ok, socket, entry} = Upload.register_entry_upload(socket, photo, self(), ref)
    # socket=Upload.unregister_completed_entry_upload(socket, photo, ref)
    a =
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

    IO.puts(
      "\n\n########## DEBUG ##########\n socket: #{inspect(socket, pretty: true)} \n########## DEBUG ##########\n\n"
    )

    a |> noreply()

    # socket
    #   |> push_event("resume_upload", %{id: ref})
    #   |> noreply()
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
        %{assigns: %{gallery: gallery, album_id: album_id, uploaded_files: uploaded_files, progress: progress}} =
          socket
      ) do
    if entry.done? do
      {:ok, photo} = create_photo(gallery, entry, album_id)
      uploaded_files = uploaded_files + 1
      start_photo_processing(photo, gallery.watermark)

      Phoenix.PubSub.broadcast(
        Picsello.PubSub,
        "gallery:#{gallery.id}",
        {:upload_success_message, upload_success_message(socket, uploaded_files)}
      )

      socket
      |> assign(uploaded_files: uploaded_files)
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

  defp assign_overall_progress(%{assigns: %{progress: progress, gallery: gallery}} = socket) do
    total_progress = GalleryUploadProgress.total_progress(progress)

    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "gallery_progress:#{gallery.id}",
      {:total_progress, total_progress}
    )

    estimate = GalleryUploadProgress.estimate_remaining(progress, DateTime.utc_now())

    if total_progress == 100 do
      Phoenix.PubSub.broadcast(Picsello.PubSub, "photo_uploaded:#{gallery.id}", :photo_upload_completed)
      # IO.inspect(parent_pid)
      Galleries.update_gallery_photo_count(gallery.id)
      Galleries.normalize_gallery_photo_positions(gallery.id)
      # send(parent_pid, :photo_upload_completed)
    end

    socket
    |> assign(:overall_progress, total_progress)
    |> assign(:estimate, estimate)
  end

  defp create_photo(gallery, entry, album_id) do
    IO.puts("\n\n########## DEBUG ##########\n album_id: #{inspect(album_id, pretty: true)} \n########## DEBUG ##########\n\n")
    Galleries.create_photo(%{
      gallery_id: gallery.id,
      album_id: album_id,
      name: entry.client_name,
      original_url: Photo.original_path(entry.client_name, gallery.id, entry.uuid),
      position: (gallery.total_count || 0) + 100
    })
  end

  defp upload_success_message(%{assigns: %{entries: entries}}, uploaded_files),
    do:
      "#{uploaded_files}/#{total(entries)} photo#{is_plural(uploaded_files)} uploaded successfully"

  defp is_plural(count) do
    if count > 1, do: "s"
  end

  defp start_photo_processing(photo, watermark) do
    ProcessingManager.start(photo, watermark)
  end
end
