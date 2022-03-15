defmodule PicselloWeb.GalleryLive.Albums do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries
  alias Picsello.Repo

  @impl true
  def mount(%{"gallery_id" => gallery_id}, _session, socket) do
    gallery = Galleries.get_gallery!(gallery_id) |> Repo.preload(:albums)

    {
      :ok,
      socket
      |> assign(:gallery_id, gallery_id)
      |> assign(:gallery, gallery)
    }
  end

  @impl true
  def handle_event(
        "open_albums_popup",
        %{},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> open_modal(PicselloWeb.GalleryLive.Settings.AddAlbumModal, %{gallery_id: gallery_id})
    |> noreply()
  end
end
