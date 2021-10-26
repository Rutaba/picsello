defmodule PicselloWeb.PhotoUploadLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  @upload_options [
    accept: ~w(.jpg .jpeg .png),
    max_entries: 50,
    max_file_size: 104_857_600,
    auto_upload: true
  ]
  @bucket "picsello-staging"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(:gcp_credentials, gcp_credentials())
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
  def handle_event("start", _params, socket) do
    send(self(), :overall_progress)
    {:noreply, socket}
  end

  def handle_info(:overall_progress, socket) do
    uploading_achievements = for entry <- socket.assigns.uploads.photo.entries, do: entry.progress
    overall_progress = Enum.sum(uploading_achievements) / Enum.count(uploading_achievements)

    unless done?(overall_progress) do
      Process.send_after(self(), :overall_progress, 500)
    end

    {:noreply, assign(socket, :overall_progress, overall_progress)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  defp handle_progress(:photo, entry, %{assigns: assigns} = socket) do
    if entry.done? do
      sign_opts = [bucket: assigns.upload_bucket, key: entry.client_name]
      upload = GCSSign.sign_url_v4(socket.assigns.gcp_credentials, sign_opts)

      {:noreply, update(socket, :uploaded_files, &(&1 ++ [upload]))}
    else
      {:noreply, socket}
    end
  end

  defp presign_entry(entry, socket) do
    uploads = socket.assigns.uploaded_files
    key = entry.client_name

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

    {:ok, params} = GCSSign.sign_post_policy_v4(socket.assigns.gcp_credentials, sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  defp total(list) when is_list(list), do: list |> length
  defp total(_), do: nil

  defp done?(progress), do: progress == 100

  defp gcp_credentials do
    Application.get_env(:gcs_sign, :gcp_credentials)
    |> File.read!()
    |> Jason.decode!()
  end
end
