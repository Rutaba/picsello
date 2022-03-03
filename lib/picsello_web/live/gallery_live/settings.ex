defmodule PicselloWeb.GalleryLive.Settings do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries
  alias PicselloWeb.GalleryLive.Settings.CustomWatermarkComponent
  alias PicselloWeb.ConfirmationComponent
  alias PicselloWeb.GalleryLive.UploadComponent

  @upload_options [
    accept: ~w(.jpg .jpeg .png image/jpeg image/png),
    max_entries: 1,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &__MODULE__.presign_cover_entry/2,
    progress: &__MODULE__.handle_cover_progress/3
  ]

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> allow_upload(:cover_photo, @upload_options)
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    socket
    |> assign(:gallery, Galleries.load_watermark_in_gallery(gallery))
    |> noreply()
  end

  @impl true
  def handle_event("open_watermark_popup", _, socket) do
    send(self(), :open_modal)
    socket |> noreply()
  end

  def handle_event("share_link", params, socket) do
    PicselloWeb.GalleryLive.Show.handle_event("client-link", params, socket)
  end

  @impl true
  def handle_event("open_watermark_deletion_popup", _, socket) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_watermark",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete watermark?",
      subtitle: "Are you sure you wish to permanently delete your
        custom watermark? You can always add another
        one later."
    })
    |> noreply()
  end

  @impl true
  def handle_info(:open_modal, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> open_modal(CustomWatermarkComponent, %{gallery: gallery})
    |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "delete_watermark"}, %{assigns: %{gallery: gallery}} = socket) do
    Galleries.delete_gallery_watermark(gallery.watermark)
    send(self(), :clear_watermarks)

    socket
    |> close_modal()
    |> preload_watermark()
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
  def handle_info({:photo_processed, _}, socket), do: noreply(socket)

  @impl true
  def handle_info(:clear_watermarks, %{assigns: %{gallery: gallery}} = socket) do
    Galleries.clear_watermarks(gallery.id)
    noreply(socket)
  end

  @impl true
  def handle_info(:expiration_saved, socket) do
    socket
    |> put_flash(:success, "The expiration date has been saved.")
    |> noreply()
  end

  defp preload_watermark(%{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.load_watermark_in_gallery(gallery))
  end
end
