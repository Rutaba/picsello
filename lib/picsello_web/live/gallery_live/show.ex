defmodule PicselloWeb.GalleryLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries
  alias Picsello.Galleries.Workers.PositionNormalizer
  alias PicselloWeb.GalleryLive.UploadComponent

  @per_page 12
  @upload_options [
    accept: ~w(.jpg .jpeg .png),
    max_entries: 1,
    max_file_size: 104_857_600,
    auto_upload: true
  ]
  @bucket "picsello-staging"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:cover_photo, nil)
     |> assign(:gcp_credentials, gcp_credentials())
     |> assign(:upload_bucket, @bucket)
     |> allow_upload(
       :cover_photo,
       Keyword.merge(@upload_options,
         external: &presign_entry/2,
         progress: &handle_progress/3
       )
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:gallery, gallery)
    |> assign(:page, 0)
    |> assign(:update_mode, "append")
    |> assign(:favorites_filter, false)
    |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event("open_upload_popup", _, socket) do
    socket
    |> open_modal(UploadComponent, %{index: "hello"})
    |> noreply()
  end

  @impl true
  def handle_event("load-more", _, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(page: page + 1)
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event("toggle_favorites", _, %{assigns: %{favorites_filter: toggle_state}} = socket) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, !toggle_state)
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event(
        "update_photo_position",
        %{"photo_id" => photo_id, "type" => type, "args" => args},
        %{assigns: %{gallery: %{id: gallery_id}}} = socket
      ) do
    Galleries.update_gallery_photo_position(
      gallery_id,
      photo_id |> String.to_integer(),
      type,
      args
    )

    PositionNormalizer.normalize(gallery_id)

    noreply(socket)
  end

  @impl true
  def handle_event("start", _params, socket) do
    socket.assigns.uploads.cover_photo
    |> case do
      %{valid?: false, ref: ref} -> {:noreply, cancel_upload(socket, :cover_photo, ref)}
      _ -> {:noreply, socket}
    end
  end

  def handle_info({:overall_progress, _upload_state}, socket) do
    send_update(self(), UploadComponent, id: "hello", overall_progress: 1)

    {:noreply, socket}
  end

  def handle_info(:close_upload_popup, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  defp handle_progress(:cover_photo, entry, %{assigns: assigns} = socket) do
    if entry.done? do
      sign_opts = [bucket: assigns.upload_bucket, key: entry.client_name, expires_in: 600_000]
      upload = GCSSign.sign_url_v4(socket.assigns.gcp_credentials, sign_opts)

      {:noreply, socket |> assign(:cover_photo, upload)}
    else
      {:noreply, socket}
    end
  end

  defp presign_entry(entry, socket) do
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

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{id: id},
             page: page,
             favorites_filter: filter
           }
         } = socket
       ) do
    assign(socket,
      photos: Galleries.get_gallery_photos(id, @per_page, page, only_favorites: filter)
    )
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:upload), do: "New Gallery"

  defp done?(progress), do: progress == 100

  defp gcp_credentials do
    Application.get_env(:gcs_sign, :gcp_credentials)
    |> File.read!()
    |> Jason.decode!()
  end
end
