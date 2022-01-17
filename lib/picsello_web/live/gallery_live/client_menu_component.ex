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

<<<<<<< HEAD
  def get_menu_items(_socket),
    do: [
      %{title: "Home", path: "#"},
      %{title: "My orders", path: "#"},
      %{title: "Help", path: "#"}
=======
  def get_menu_items(socket, gallery) do
    [
      %{title: "Home", path: "/home"},
      %{title: "Shop", path: "#"},
      %{
        title: "My orders",
        path: Routes.gallery_client_orders_path(socket, :show, gallery.client_link_hash)
      }
>>>>>>> f1655af7 (client_orders)
    ]
  end
end
