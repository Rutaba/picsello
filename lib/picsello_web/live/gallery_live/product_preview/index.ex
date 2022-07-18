defmodule PicselloWeb.GalleryLive.ProductPreview.Index do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_photographer"
    ]

  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Galleries, Repo}
  alias PicselloWeb.GalleryLive.ProductPreview.Preview

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(total_progress: 0)
    |> assign(:photos_error_count, 0)
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    gallery = Galleries.get_gallery!(id) |> Repo.preload([:albums, :photographer])
    prepare_gallery(gallery)

    socket
    |> assign(
      gallery: gallery,
      page_title: page_title(socket.assigns.live_action),
      products: Galleries.products(gallery)
    )
    |> is_mobile(params)
    |> noreply()
  end

  @impl true
  def handle_event("back-to-navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket |> assign(:is_mobile, !is_mobile) |> noreply
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
  def handle_event("client-link", _, socket) do
    share_gallery(socket)
  end

  @impl true
  def handle_info({:message_composed, message_changeset}, socket) do
    add_message_and_notify(socket, message_changeset, "gallery")
  end

  @impl true
  def handle_info(
        {:save, %{title: title}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> close_modal()
    |> assign(products: Galleries.products(gallery))
    |> put_flash(:success, "#{title} successfully updated")
    |> noreply
  end

  @impl true
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
  end

  @impl true
  def handle_info({:upload_success_message, success_message}, socket) do
    socket |> put_flash(:success, success_message) |> noreply()
  end

  @impl true
  def handle_info(
        {:photos_error, %{photos_error_count: photos_error_count, entries: entries}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    if length(entries) > 0, do: inprogress_upload_broadcast(gallery.id, entries)

    socket
    |> assign(:photos_error_count, photos_error_count)
    |> noreply()
  end

  defp page_title(:index), do: "Product Previews"
end
