defmodule PicselloWeb.GalleryLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"] # todo: remove when user logged in

  alias Picsello.Galleries

  @per_page 12

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
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
    Galleries.PositionNormalizer.normalize(gallery_id)

    noreply(socket)
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
  defp page_title(:edit), do: "Edit Gallery"
end
