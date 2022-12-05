defmodule PicselloWeb.GalleryLive.Photos.Photo.ClientPhoto do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Photos
  alias PicselloWeb.Router.Helpers, as: Routes

  import PicselloWeb.GalleryLive.Photos.Photo.Shared

  @impl true
  def update(%{photo: photo} = assigns, socket) do
    socket
    |> assign(
      preview_photo_id: nil,
      component: false,
      client_liked_album: false,
      is_proofing: assigns[:is_proofing] || false,
      client_link_hash: Map.get(assigns, :client_link_hash),
      is_liked: photo.client_liked,
      url: Routes.static_path(PicselloWeb.Endpoint, "/images/gallery-icon.svg")
    )
    |> assign(assigns)
    |> ok
  end

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    {:ok, _} = Photos.toggle_liked(id)
    socket |> noreply()
  end

  defp wrapper_style(width, %{aspect_ratio: aspect_ratio}),
  do: "width: #{width}px;height: #{width / aspect_ratio}px;"
end
