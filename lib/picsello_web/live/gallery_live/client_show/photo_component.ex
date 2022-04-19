defmodule PicselloWeb.GalleryLive.ClientShow.PhotoComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Phoenix.LiveView.JS
  alias Picsello.Photos

  @impl true
  def mount(socket) do
    socket
    |> assign(:preview_photo_id, nil)
    |> ok
  end

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    {:ok, photo} = Photos.toggle_liked(id)

    favorites_update =
      if photo.client_liked,
        do: :increase_favorites_count,
        else: :reduce_favorites_count

    send(self(), favorites_update)

    socket |> noreply()
  end

  defp js_like_click(js \\ %JS{}, id, target) do
    js
    |> JS.push("like", target: target, value: %{id: id})
    |> JS.toggle(to: "#photo-#{id}-liked")
    |> JS.toggle(to: "#photo-#{id}-to-like")
  end

  defp wrapper_style(width, photo) do
    """
    width: #{width}px;
    height: #{width / photo.aspect_ratio}px;
    """
  end
end
