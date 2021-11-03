defmodule PicselloWeb.GalleryLive.UploadComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries

  @upload_options [
    accept: ~w(.jpg .jpeg .png),
    max_entries: 50,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &__MODULE__.presign_entry/2,
    progress: &__MODULE__.handle_progress/3
  ]
  @bucket "picsello-staging"

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, 0)
     |> assign(:upload_bucket, @bucket)
     |> assign(:overall_progress, 0)
     |> assign(:update_mode, "prepend")
     |> allow_upload(:photo, @upload_options)}
  end

  @impl true
  def handle_event("start", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.photo.entries, socket, fn
        %{valid?: false, ref: ref}, socket -> cancel_upload(socket, :photo, ref)
        _, socket -> socket
      end)
      |> assign(:update_mode, "prepend")

    {:noreply, socket}
  end

  @impl true
  def handle_event("close", _, socket) do
    send(self(), :close_upload_popup)

    socket |> noreply()
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    socket
    |> assign(:update_mode, "replace")
    |> cancel_upload(:photo, ref)
    |> noreply()
  end

  defp assign_overall_progress(socket) do
    total_progress =
      socket.assigns.uploads.photo.entries
      |> Enum.map(& &1.progress)
      |> then(&(Enum.sum(&1) / Enum.count(&1)))
      |> trunc

    if total_progress == 100 do
      send(self(), :close_upload_popup)
      send(self(), {:update_total_count, socket.assigns.uploaded_files})
      send(self(), :gallery_position_normalize)
    end

    socket
    |> assign(:overall_progress, total_progress)
  end

  def handle_progress(
        :photo,
        entry,
        %{assigns: %{gallery: gallery, uploaded_files: uploaded_files}} = socket
      ) do
    if entry.done? do
      {:ok, _photo} =
        Galleries.create_photo(%{
          gallery_id: gallery.id,
          name: entry.client_name,
          original_url: entry.uuid,
          client_copy_url: entry.uuid,
          preview_url: entry.uuid,
          position: gallery.total_count + 100,
          aspect_ratio: 1
        })

      socket
      |> assign(uploaded_files: uploaded_files + 1)
      |> assign_overall_progress()
      |> noreply()
    else
      socket
      |> assign_overall_progress()
      |> noreply()
    end
  end

  def presign_entry(entry, socket) do
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

  defp overall_progress(assigns) do
    ~H"""
    Uploading <%= @uploads %> of <%= total(@entries) %> photos
    """
  end

  defp gcp_credentials() do
    conf = Application.get_env(:gcs_sign, :gcp_credentials)

    Map.put(conf, "private_key", conf["private_key"] |> Base.decode64!())
  end
end
