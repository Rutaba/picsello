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

  def get_menu_items(_socket),
    do: [
      %{title: "Home", path: "#"},
      %{title: "Shop", path: "#"},
      %{title: "My orders", path: "#"},
      %{title: "Help", path: "#"}
    ]
end
