defmodule PicselloWeb.GalleryLive.Settings.SidebarComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def update(%{id: id, gallery: gallery}, socket) do
    {
      :ok,
      socket
      |> assign(:id, id)
      |> assign(:gallery, gallery)
    }
  end
end
