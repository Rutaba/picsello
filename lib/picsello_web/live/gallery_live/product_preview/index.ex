defmodule PicselloWeb.GalleryLive.ProductPreview.Index do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  alias Picsello.{Galleries, Repo}
  alias PicselloWeb.GalleryLive.ProductPreview.Preview
  alias PicselloWeb.GalleryLive.Photos.Upload

  @impl true
  def mount(_params, _session, socket) do
      socket
      |> assign(total_progress: 0)
      |> ok()
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id) |> Repo.preload(:albums)

    socket
    |> assign(
      gallery: gallery,
      page_title: page_title(socket.assigns.live_action),
      products: Galleries.products(gallery)
    )
    |> noreply()
  end

  @impl true
  def handle_info(
        {:save, %{title: title}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> close_modal()
    |> assign(products: Galleries.products(gallery))
    |> put_flash(:gallery_success, "#{title} preview successfully updated")
    |> noreply
  end

  @impl true
  def handle_event(
        "edit",
        %{"product_id" => product_id},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> open_modal(
      PicselloWeb.GalleryLive.ProductPreview.EditProduct,
      %{product_id: product_id, gallery_id: gallery.id}
    )
    |> noreply
  end

  @impl true
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
  end

  defp page_title(:index), do: "Product Previews"
end
