defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Cart

  @impl true
  def mount(_params, _session, %{assigns: %{gallery: gallery}} = socket) do
    case Cart.get_unconfirmed_order(gallery.id) do
      {:ok, order} ->
        socket
        |> assign(:order, order)
        |> ok()
      _ -> 
        socket
        |> push_redirect(to: Routes.gallery_client_show_path(socket, :show, gallery.client_link_hash))
        |> ok()
    end
  end
end
