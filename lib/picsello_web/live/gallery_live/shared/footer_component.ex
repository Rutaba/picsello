defmodule PicselloWeb.GalleryLive.Shared.FooterComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries
  alias Picsello.Albums
  alias Picsello.Repo

  import PicselloWeb.GalleryLive.Shared, only: [disabled?: 1]

  @impl true
  def update(%{gallery: gallery, total_progress: total_progress}, socket) do
    gallery = gallery |> Galleries.set_gallery_hash()

    socket
    |> assign(url: url(socket, gallery))
    |> assign(gallery: gallery)
    |> assign(uploading?: total_progress not in [100, 0])
    |> ok()
  end

  defp url(socket, %{type: :standard, client_link_hash: hash}) do
    Routes.gallery_client_index_path(socket, :index, hash)
  end

  defp url(socket, gallery) do
    %{albums: [album]} = gallery |> Repo.preload(:albums)
    %{client_link_hash: hash} = Albums.set_album_hash(album)
    Routes.gallery_client_album_path(socket, :proofing_album, hash)
  end
end
