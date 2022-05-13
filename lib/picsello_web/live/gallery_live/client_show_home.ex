defmodule PicselloWeb.GalleryLive.ClientShowHome do
  @moduledoc false

  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

    alias Picsello.Galleries

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(photo_updates: "false", download_all_visible: false)
    |> ok()
  end

  @impl true
  def handle_event(
        "view_gallery",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    socket
    |> push_redirect(to: Routes.gallery_client_show_path(socket, :show, hash))
    |> noreply()
  end

end
