defmodule PicselloWeb.GalleryLive.Settings.CustomWatermarkComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries
  alias Picsello.Galleries.Workers.PhotoStorage

  @upload_options [
    accept: ~w(.png image/png),
    max_entries: 1,
    max_file_size: String.to_integer(Application.compile_env(:picsello, :photo_max_file_size)),
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
  def update(%{id: id, gallery: gallery}, socket) do
    {:ok,
     socket
     |> assign(:id, id)
     |> assign(:gallery, gallery)
     |> assign(:watermark, gallery.watermark)
     |> assign_default_changeset()}
  end

  @impl true
  def handle_event("image_case", _params, socket) do
    socket
    |> assign(:case, :image)
    |> assign_default_changeset()
    |> assign(:ready_to_save, false)
    |> noreply()
  end

  @impl true
  def handle_event("text_case", _params, socket) do
    socket
    |> assign(:case, :text)
    |> assign_default_changeset()
    |> assign(:ready_to_save, false)
    |> noreply()
  end

  @impl true
  def handle_event("validate_image_input", _params, socket) do
    socket
    |> handle_image_validation()
    |> noreply
  end

  @impl true
  def handle_event("validate_text_input", params, socket) do
    socket
    |> assign_text_watermark_change(params)
    |> noreply
  end

  @impl true
  def handle_event("save", _, %{assigns: %{gallery: gallery, changeset: changeset}} = socket) do
    {:ok, _gallery} = Galleries.save_gallery_watermark(gallery, changeset)

    send(self(), :close_watermark_popup)
    send(self(), :preload_watermark)

    socket |> noreply()
  end

  @impl true
  def handle_event("delete", _, socket) do
    socket
    |> delete_watermark()
    |> noreply()
  end

  @impl true
  def handle_event("close", _, socket) do
    send(self(), :close_watermark_popup)
    socket |> noreply()
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
      conditions: [
        [
          "content-length-range",
          0,
          String.to_integer(Application.get_env(:picsello, :photo_max_file_size))
        ]
      ]
    ]

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  def handle_image_progress(:image, %{done?: false}, socket), do: socket |> noreply()

  def handle_image_progress(:image, image, socket) do
    socket
    |> assign_image_watermark_change(image)
    |> noreply()
  end

  defp assign_default_changeset(%{assigns: %{watermark: watermark}} = socket) do
    socket
    |> assign(:changeset, Galleries.gallery_watermark_change(watermark))
  end

  defp handle_image_validation(socket) do
    case socket.assigns.uploads.image.entries do
      %{valid?: false, ref: ref} -> cancel_upload(socket, :photo, ref)
      _ -> socket
    end
  end

  defp assign_image_watermark_change(%{assigns: %{watermark: watermark}} = socket, image) do
    changeset =
      Galleries.gallery_image_watermark_change(watermark, %{
        name: image.client_name,
        size: image.client_size
      })

    socket
    |> assign(:changeset, changeset)
    |> assign(:ready_to_save, changeset.valid?)
  end

  defp assign_text_watermark_change(%{assigns: %{watermark: watermark}} = socket, %{
         "watermark" => %{"text" => text}
       }) do
    changeset = Galleries.gallery_text_watermark_change(watermark, %{text: text})

    socket
    |> assign(:changeset, changeset)
    |> assign(:ready_to_save, changeset.valid?)
  end

  defp delete_watermark(%{assigns: %{gallery: gallery, watermark: watermark}} = socket) do
    Galleries.delete_gallery_watermark(watermark)
    send(self(), :clear_watermarks)
    send(self(), :preload_watermark)

    socket
    |> assign(:gallery, Galleries.load_watermark_in_gallery(gallery))
    |> assign(watermark: nil)
    |> assign_default_changeset()
  end

  defp watermark_type(%{type: "image"}), do: :image
  defp watermark_type(%{type: "text"}), do: :text
  defp watermark_type(_), do: :undefined
end
