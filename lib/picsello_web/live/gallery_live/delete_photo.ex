defmodule PicselloWeb.GalleryLive.DeletePhoto do
  @moduledoc false
  use PicselloWeb, :live_component

  def handle_event("confirm", _, %{assigns: %{type: :cover}} = socket) do
    send(self(), :confirm_cover_photo_deletion)
    {:noreply, socket}
  end

  def handle_event("confirm", _, %{assigns: %{type: :plain, photo_id: id}} = socket) do
    send(self(), {:confirm_photo_deletion, id})
    {:noreply, socket}
  end

  def handle_event("cancel", _, socket) do
    send(self(), :cancel_photo_deletion)
    {:noreply, socket}
  end
end
