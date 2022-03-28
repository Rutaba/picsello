defmodule PicselloWeb.GalleryLive.PhotoComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Phoenix.LiveView.JS
  alias Picsello.Galleries

  @impl true
  def mount(socket) do
    socket
    |> assign(preview_photo_id: nil, is_removed: false)
    |> ok
  end

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    {:ok, photo} =
      Galleries.get_photo(id)
      |> Galleries.mark_photo_as_liked()

    favorites_update =
      if photo.client_liked,
        do: :increase_favorites_count,
        else: :reduce_favorites_count

    send(self(), favorites_update)

    socket |> noreply()
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

  defp wrapper_style(width, photo) do
    height =
      if (photo.watermarked_preview_url || photo.preview_url) && photo.aspect_ratio,
        do: width / photo.aspect_ratio,
        else: 450

    """
    width: #{width}px;
    height: #{height}px;
    """
  end
end
