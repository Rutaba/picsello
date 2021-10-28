defmodule PicselloWeb.GalleryLive.UploadComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries

  @upload_options [
    accept: ~w(.jpg .jpeg .png),
    max_entries: 50,
    max_file_size: 104_857_600,
    auto_upload: true
  ]
  @bucket "picsello-staging"

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, 0)
     |> assign(:upload_bucket, @bucket)
     |> assign(:overall_progress, 0)
     |> allow_upload(
       :photo,
       Keyword.merge(@upload_options,
         external: &presign_entry/2,
         progress: &handle_progress/3
       )
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(:id, assigns.id)
     |> assign(:gallery, assigns.gallery)}
  end

  @impl true
  def handle_event("start", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.photo.entries, socket, fn
        %{valid?: false, ref: ref}, socket -> cancel_upload(socket, :photo, ref)
        _, socket -> socket
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close", _, socket) do
    send(self(), :close_upload_popup)

    socket |> noreply()
  end

  @impl true
  def handle_event("overall_progress", _, socket) do
    uploading_achievements = for entry <- socket.assigns.uploads.photo.entries, do: entry.progress
    overall_progress = Enum.sum(uploading_achievements) / Enum.count(uploading_achievements)
    socket = socket |> assign(:overall_progress, overall_progress)

    unless done?(overall_progress) do
      Process.send_after(self(), {:overall_progress, socket}, 500)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  defp handle_progress(:photo, entry, %{assigns: assigns} = socket) do
    if entry.done? do
      {:ok, _photo} =
        Galleries.create_photo(%{
          gallery_id: assigns.gallery.id,
          name: entry.client_name,
          original_url: entry.uuid,
          client_copy_url: entry.uuid,
          position: 1,
          aspect_ratio: 1
        })

      {:noreply, assign(socket, :uploaded_files, assigns.uploaded_files + 1)}
    else
      {:noreply, socket}
    end
  end

  defp presign_entry(entry, socket) do
    key = entry.uuid <> Path.extname(entry.client_name)

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

    {:ok, params} = GCSSign.sign_post_policy_v4(gcp_credentials(), sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  defp total(list) when is_list(list), do: list |> length
  defp total(_), do: nil

  defp done?(progress), do: progress == 100

  defp overall_progress(assigns) do
    ~H"""
    Uploaded <%= total(@uploads) %> of <%= total(@entries) %> photos
    """
  end

  defp gcp_credentials() do
    conf = Application.get_env(:gcs_sign, :gcp_credentials)

    Map.put(conf, "private_key", conf["private_key"] |> Base.decode64!())
  end
end
