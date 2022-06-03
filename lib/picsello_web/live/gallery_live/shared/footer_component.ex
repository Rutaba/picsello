defmodule PicselloWeb.GalleryLive.Shared.FooterComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries

  @impl true
  def update(%{gallery: gallery}, socket) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    socket
    |> assign(url: Routes.gallery_client_index_path(socket, :index, hash))
    |> ok()
  end
end
