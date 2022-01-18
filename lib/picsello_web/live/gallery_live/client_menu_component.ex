defmodule PicselloWeb.GalleryLive.ClientMenuComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @defaults %{
    cart_count: 0,
    cart_route: nil
  }

  def update(assigns, socket) do
    socket
    |> assign(Map.merge(@defaults, assigns))
    |> then(&{:ok, &1})
  end

  def get_menu_items(socket, gallery) do
    [
      %{title: "Home", path: Routes.gallery_client_show_path(socket, :show, gallery.client_link_hash)},
      %{title: "My orders", path: Routes.gallery_client_orders_path(socket, :show, gallery.client_link_hash)}
    ]
  end
end
