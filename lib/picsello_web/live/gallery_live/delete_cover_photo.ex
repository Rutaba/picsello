defmodule PicselloWeb.GalleryLive.DeleteCoverPhoto do
  @moduledoc false
  use PicselloWeb, :live_component

  def handle_event("close", params, socket) do
    send(self(), {:close_delete_cover_photo, params})
    {:noreply, socket}
  end
end
