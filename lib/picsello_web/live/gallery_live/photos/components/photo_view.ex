defmodule PicselloWeb.GalleryLive.Photos.PhotoView do
  @moduledoc "Component to view a photo"

  use PicselloWeb, :live_component
  import PicselloWeb.LiveHelpers

  alias Picsello.Galleries

  @impl true
  def update(%{photo_id: photo_id}, socket) do
    photo = Galleries.get_photo(photo_id)

    socket
    |> assign(url: path(photo.watermarked_preview_url || photo.preview_url))
    |> ok()
  end

  @impl true
  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="choose-product lg:h-full lg:overflow-y-scroll w-full flex lg:justify-between lg:px-0 lg:pl-16 xl:pl-20 lg:pr-16 xl:pr-20">
        <div class="choose-product-item w-full h-96 lg:h-full lg:w-full mb-5 lg:mb-0 relative">
          <div id="wrapper" class="wrapper h-full justify-center">
            <a phx-click="close" phx-target={@myself} class="absolute p-2 rounded-full cursor-pointer right-5 top-5">
              <.icon name="close-x" class="w-3 h-3 lg:w-3 lg:h-3 text-white stroke-current stroke-2" />
            </a>
            <img src={ @url } class="max-w-full">
          </div>
        </div>
      </div>
    </div>
    """
  end
end
