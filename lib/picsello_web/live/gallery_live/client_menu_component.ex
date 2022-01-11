defmodule PicselloWeb.GalleryLive.ClientMenuComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  def get_menu_items(_socket),
    do: [
      %{title: "Home", path: "#"},
      %{title: "Shop", path: "#"},
      %{title: "My orders", path: "#"},
      %{title: "Help", path: "#"}
    ]
end
