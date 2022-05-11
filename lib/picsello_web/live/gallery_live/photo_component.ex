defmodule PicselloWeb.GalleryLive.PhotoComponent do
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

  @impl true
  def handle_event("click", _, socket) do
    socket
    |> noreply()
  end

  defp js_like_click(js \\ %JS{}, id, target) do
    js
    |> JS.push("like", target: target, value: %{id: id})
    |> JS.toggle(to: "#photo-#{id}-liked")
    |> JS.toggle(to: "#photo-#{id}-to-like")
  end

  defp toggle_border(js \\ %JS{}, id, is_gallery_category_page) do
    if is_gallery_category_page do
      js
      |> JS.dispatch("click", to: "#photo-#{id} > img")
      |> JS.add_class(
        "before:absolute before:border-8 before:border-blue-planning-300 before:left-0 before:top-0 before:bottom-0 before:right-0 before:z-10 selected",
        to: "#item-#{id}"
      )
    else
      js |> JS.dispatch("click", to: "#photo-#{id} > img")
    end
  end
end
