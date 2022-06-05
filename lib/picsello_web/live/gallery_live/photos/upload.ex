defmodule PicselloWeb.GalleryLive.Photos.Upload do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Phoenix.LiveView.UploadConfig

  alias Picsello.Galleries
  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.PhotoProcessing.GalleryUploadProgress
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Phoenix.PubSub

  @upload_options [
    accept: ~w(.jpg .jpeg .png image/jpeg image/png),
    max_entries: 2,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &__MODULE__.presign_entry/2,
    progress: &__MODULE__.handle_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def mount(_params, %{"gallery_id" => gallery_id} = session, socket) do
    gallery =
      Galleries.get_gallery!(gallery_id)
      |> Galleries.load_watermark_in_gallery()

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "upload_update")
      PubSub.subscribe(Picsello.PubSub, "upload_pending_photos")
      PubSub.subscribe(Picsello.PubSub, "delete_photos")
    end

    {:ok,
     socket
     |> assign(:upload_bucket, @bucket)
     |> assign(:view, Map.get(session, "view", "add_button"))
     |> assign(:album_id, Map.get(session, "album_id", nil))
     |> assign(:gallery, gallery)
     |> assign(:invalid_photos, [])
     |> assign(:pending_photos, [])
     |> assign(:inprogress_photos, [])
     |> assign(:photos_error_count, 0)
     |> assign(:overall_progress, 0)
     |> assign(:uploaded_files, 0)
     |> assign(:estimate, "n/a")
     |> assign(:progress, %GalleryUploadProgress{})
     |> assign(:update_mode, "append")
     |> allow_upload(:photo, @upload_options), layout: false}
  end

  @impl true
  def handle_event("start", _params, %{assigns: %{gallery: gallery, inprogress_photos: inprogress_photos, album_id: album_id}} = socket) do
    gallery = Galleries.load_watermark_in_gallery(gallery)

    if Enum.empty?(inprogress_photos) do
      socket
      |> assign(:persisted_album_id, album_id)
    else
       socket
    end
    |> apply_limits()
    |> update_uploader()
    |> cancel_unknown_entries()
    |> update_progress()
    |> assign(:update_mode, "append")
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

  @impl true
  def handle_info(
        {:upload_update, %{album_id: album_id}},
        %{assigns: %{photos_error_count: photos_error_count}} = socket
      ) do
    photos_error_count > 0 && photos_error_broadcast(socket)

    socket
    |> assign(:album_id, album_id)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:delete_photos, %{index: index, delete_from: delete_from}},
        %{assigns: %{photos_error_count: photos_error_count} = assigns} = socket
      ) do

    cond do
      is_nil(delete_from) ->
        socket |> photos_error_broadcast()
      is_list(index) ->
        socket
        |> assign(:invalid_photos, [])
        |> assign(:pending_photos, [])
        |> assign(:inprogress_photos, [])
        |> assign(:entries, [])
        |> assign(:photos_error_count, 0)
        |> then(&photos_error_broadcast(&1))
      true ->
        {_, pending_entries} = assigns[delete_from] |> List.pop_at(index)

        socket
        |> assign(delete_from, pending_entries)
        |> assign(:photos_error_count, photos_error_count - 1)
    end
    |> noreply()
  end

  @impl true
  def handle_info(
        {:upload_pending_photos, %{index: index}},
        %{assigns: %{gallery: gallery, pending_photos: pending_photos, photos_error_count: photos_error_count}} = socket
      ) do
    IO.inspect(pending_photos)
    gallery = Galleries.load_watermark_in_gallery(gallery)

    if is_list(index) do
      {valid_entries, pending_entries} =
        Enum.chunk_every(pending_photos, Keyword.get(@upload_options, :max_entries))
        |> List.pop_at(0)

      valid_entries = valid_entries || []

      socket
      |> assign(:pending_photos, List.flatten(pending_entries))
      |> assign(:photos_error_count, photos_error_count - length(valid_entries))
      |> assign(:inprogress_photos, valid_entries)
      |> then(&photos_error_broadcast(&1))
    else
      {valid_entry, pending_entries} = pending_photos |> List.pop_at(index)

      socket
      |> assign(:pending_photos, pending_entries)
      |> assign(:photos_error_count, photos_error_count - 1)
      |> assign(:inprogress_photos, if(is_nil(valid_entry), do: [], else: [valid_entry]))
    end
    |> update_uploader()
    |> cancel_unknown_entries()
    |> update_progress()
    |> assign(:gallery, gallery)
    |> push_event("resume_upload", %{id: socket.assigns.uploads.photo.ref})
    |> noreply()
  end

  def handle_progress(
        :photo,
        entry,
        %{
          assigns: %{
            gallery: gallery,
            persisted_album_id: persisted_album_id,
            uploaded_files: uploaded_files,
            progress: progress
          }
        } = socket
      ) do
    if entry.done? do
      {:ok, photo} = create_photo(gallery, entry, persisted_album_id)
      uploaded_files = uploaded_files + 1
      start_photo_processing(photo, gallery.watermark)

      Phoenix.PubSub.broadcast(
        Picsello.PubSub,
        "gallery:#{gallery.id}",
        {:upload_success_message, upload_success_message(socket)}
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

    gallery_progress_broadcast(socket, total_progress)
    estimate = GalleryUploadProgress.estimate_remaining(progress, DateTime.utc_now())

    if total_progress == 100 do
      Phoenix.PubSub.broadcast(
        Picsello.PubSub,
        "photo_uploaded:#{gallery.id}",
        :photo_upload_completed
      )

      Galleries.update_gallery_photo_count(gallery.id)
      Galleries.normalize_gallery_photo_positions(gallery.id)
    end

    socket
    |> assign(:overall_progress, total_progress)
    |> assign(:estimate, estimate)
  end

  defp photos_error_broadcast(%{assigns: %{gallery: gallery, photos_error_count: photos_error_count, invalid_photos: invalid_photos, pending_photos: pending_photos}} = socket) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "photos_error:#{gallery.id}",
      {:photos_error, invalid_photos, pending_photos, photos_error_count}
    )
    socket
  end

  defp gallery_progress_broadcast(%{assigns: %{gallery: gallery, pending_photos: pending_photos}}, total_progress) do
    IO.inspect(length(pending_photos))
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "gallery_progress:#{gallery.id}",
      {:total_progress, total_progress}
    )
  end

  defp create_photo(gallery, entry, album_id) do
    Galleries.create_photo(%{
      gallery_id: gallery.id,
      album_id: album_id,
      name: entry.client_name,
      original_url: Photo.original_path(entry.client_name, gallery.id, entry.uuid),
      position: (gallery.total_count || 0) + 100
    })
  end

  defp upload_success_message(%{assigns: %{entries: entries, inprogress_photos: inprogress_photos}}) do
    uploaded = length(inprogress_photos)
    "#{uploaded}/#{total(entries)} #{ngettext("photo", "photos", uploaded)} uploaded successfully"
  end

  defp start_photo_processing(photo, watermark) do
    ProcessingManager.start(photo, watermark)
  end

  defp apply_limits(%{assigns: %{pending_photos: pending_photos}} = socket) do
    IO.inspect(pending_photos)
    if(Enum.empty?(pending_photos)) do
      entries =
        socket.assigns.uploads.photo.entries
        |> Enum.filter(& !&1.done?)

      {valid, invalid} = max_size_limit(entries)
      {valid_entries, pending_entries} = max_entries_limit(valid)
      pending_entries = List.flatten(pending_entries)
      IO.inspect(entries)
      IO.inspect(invalid)
      IO.inspect(pending_entries)
      IO.inspect(valid_entries)
      socket
      |> assign(:invalid_photos, invalid)
      |> assign(:pending_photos, pending_entries)
      |> assign(:photos_error_count, length(pending_entries) + length(invalid))
      |> assign(:inprogress_photos, valid_entries || [])
      |> assign(:entries, entries)
    else
      socket
    end
  end

  defp max_entries_limit(entries) do
    Enum.chunk_every(entries, Keyword.get(@upload_options, :max_entries))
    |> List.pop_at(0)
  end

  defp max_size_limit(entries) do
    Enum.reduce(entries, {[], []}, fn entry, {valid, invalid} ->
      if entry.client_size < Keyword.get(@upload_options, :max_file_size) do
        {[entry | valid], invalid}
      else
        {valid, [entry | invalid]}
      end
    end)
  end

  defp update_uploader(%{assigns: %{inprogress_photos: inprogress_photos, uploads: uploads}} = socket) do
    upload_config = Map.fetch!(uploads || %{}, :photo)

    photo = %UploadConfig{
      upload_config
      | entries: inprogress_photos,
        errors: []
    }

    socket
    |> assign(:uploads, put_in(socket.assigns.uploads, [:photo], photo))
  end

  defp update_progress(%{assigns: %{inprogress_photos: inprogress_photos}} = socket) do
    Enum.empty?(inprogress_photos) && photos_error_broadcast(socket)

    socket
    |> assign(
      :progress,
      Enum.reduce(
        inprogress_photos,
        socket.assigns.progress,
        fn entry, progress -> GalleryUploadProgress.add_entry(progress, entry) end
      )
    )
  end

  defp cancel_unknown_entries(%{assigns: %{inprogress_photos: inprogress_photos}} = socket) do
    Enum.reduce(inprogress_photos, socket, fn
      %{valid?: false, ref: ref}, socket -> cancel_upload(socket, :photo, ref)
      _, socket -> socket
    end)
  end
end
