defmodule PicselloWeb.GalleryLive.Shared.FooterComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries
  alias Picsello.Albums

  @impl true
  def update(%{gallery: gallery, total_progress: total_progress}, socket) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    albums = Albums.get_albums_by_gallery_id(gallery.id)

    proofing_album =
      for album <- albums do
        if album.is_proofing, do: true, else: false
      end

    uploading =
      if total_progress == 100 || total_progress == 0 do
        false
      else
        true
      end

    socket
    |> assign(:proofing_exists?, Enum.any?(proofing_album))
    |> assign(url: Routes.gallery_client_index_path(socket, :index, hash))
    |> assign(disabled: gallery.disabled)
    |> assign(uploading: uploading)
    |> ok()
  end
end
