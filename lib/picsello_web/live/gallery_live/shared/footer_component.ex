defmodule PicselloWeb.GalleryLive.Shared.FooterComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries
  alias Picsello.Albums

  @impl true
  def update(%{gallery: gallery}, socket) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    albums = Albums.get_albums_by_gallery_id(gallery.id)
    proofing_album = for album <- albums do
        if album.is_proofing, do: true, else: false
      end

    socket
    |> assign(:proofing_exists?, Enum.any?(proofing_album))
    |> assign(url: Routes.gallery_client_index_path(socket, :index, hash))
    |> ok()
  end
end
