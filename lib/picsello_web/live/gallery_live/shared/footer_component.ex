defmodule PicselloWeb.GalleryLive.Shared.FooterComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok
  end

  @impl true
  def handle_event(
        "preview_gallery",
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
