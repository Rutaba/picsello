defmodule PicselloWeb.GalleryLive.Settings do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries
  alias PicselloWeb.GalleryLive.CustomWatermarkComponent

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    socket
    |> assign(:gallery, Galleries.load_gallery_watermark(gallery))
    |> noreply()
  end

  @impl true
  def handle_event("open_watermark_popup", _, socket) do
    send(self(), :open_modal)
    socket |> noreply()
  end

  @impl true
  def handle_event("delete_watermark", _, %{assigns: %{gallery: gallery}} = socket) do
    Galleries.delete_gallery_watermark(gallery.watermark)
    
    socket 
    |> preload_watermark()
    |> noreply()
  end

  @impl true
  def handle_info(:open_modal, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> open_modal(CustomWatermarkComponent, %{gallery: gallery})
    |> noreply()
  end

  @impl true
  def handle_info(:close_watermark_popup, socket) do
    socket |> close_modal() |> noreply()
  end

  @impl true
  def handle_info(:preload_watermark, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> preload_watermark()
    |> noreply()
  end

  defp preload_watermark(%{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.load_gallery_watermark(gallery))
  end
end
