defmodule PicselloWeb.GalleryLive.CustomWatermarkComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries

  @upload_options [
    accept: ~w(.png),
    max_entries: 1,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &__MODULE__.presign_image/2,
    progress: &__MODULE__.handle_image_progress/3
  ]
  @bucket "picsello-staging"

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:upload_bucket, @bucket)
     |> assign(:case, :image)
     |> assign(:ready_to_save, false)
     |> allow_upload(:image, @upload_options)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(:id, assigns.id)
     |> assign(:watermark, assigns.watermark)
     |> assign(:changeset, Galleries.gallery_watermark_change(assigns.watermark))
     |> assign(:gallery, assigns.gallery)}
  end

  @impl true
  def handle_event("image_case", _params, socket) do
    socket
    |> assign(:case, :image)
    |> assign(:changeset, Galleries.gallery_watermark_change(socket.assigns.watermark))
    |> assign(:ready_to_save, false)
    |> noreply()
  end

  @impl true
  def handle_event("text_case", _params, socket) do
    socket
    |> assign(:case, :text)
    |> assign(:changeset, Galleries.gallery_watermark_change(socket.assigns.watermark))
    |> assign(:ready_to_save, false)
    |> noreply()
  end

  @impl true
  def handle_event("validate_image_input", _params, socket) do
    socket |> handle_image_validation() |> noreply
  end

  @impl true
  def handle_event("validate_text_input", params, socket) do
    socket |> assign_text_watermark_change(params) |> noreply
  end

  @impl true
  def handle_event("save", _, socket) do
    socket |> assign_watermark() |> noreply()
  end

  def presign_image(image, %{assigns: %{gallery: gallery}} = socket) do
    key = "galleries/#{gallery.id}/watermark.png"

    sign_opts = [
      expires_in: 600,
      bucket: socket.assigns.upload_bucket,
      key: key,
      fields: %{
        "content-type" => image.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, 104_857_600]]
    ]

    {:ok, params} = GCSSign.sign_post_policy_v4(gcp_credentials(), sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  def handle_image_progress(:image, %{done?: false}, socket), do: socket |> noreply()

  def handle_image_progress(:image, image, socket) do
    socket
    |> assign_image_watermark_change(image)
    |> assign(:ready_to_save, true)
    |> noreply()
  end

  defp handle_image_validation(socket) do
    case socket.assigns.uploads.image.entries do
      %{valid?: false, ref: ref} -> cancel_upload(socket, :photo, ref)
      _ -> socket
    end
  end

  defp assign_image_watermark_change(%{assigns: %{watermark: watermark}} = socket, image) do
    socket
    |> assign(
      :changeset,
      Galleries.gallery_image_watermark_change(watermark, %{
        name: image.client_name,
        size: image.client_size
      })
    )
  end

  defp assign_text_watermark_change(%{assigns: %{watermark: watermark}} = socket, %{
         "watermark" => %{"text" => text}
       }) do
    socket
    |> assign(:changeset, Galleries.gallery_text_watermark_change(watermark, %{text: text}))
  end

  defp assign_watermark(%{assigns: %{gallery: gallery, changeset: changeset}} = socket) do
    {:ok, gallery} = Galleries.save_gallery_watermark(gallery, changeset)
    socket |> assign(:watermark, gallery.watermark)
  end

  defp gcp_credentials() do
    conf = Application.get_env(:gcs_sign, :gcp_credentials)

    Map.put(conf, "private_key", conf["private_key"] |> Base.decode64!())
  end
end
