defmodule PicselloWeb.GalleryLive.Photos.PhotoView do
  @moduledoc "Component to view a photo"

  use PicselloWeb, :live_component
  import PicselloWeb.LiveHelpers
  import PicselloWeb.GalleryLive.Photos.Photo.Shared, only: [js_like_click: 2]

  alias Picsello.Galleries
  alias Picsello.Photos

  @impl true
  def update(%{photo_id: photo_id, photo_ids: _photo_ids} = assigns, socket) do
    socket
    |> assign_photo(photo_id)
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def handle_event(
        "close",
        %{"photo_id" => photo_id},
        %{assigns: %{from: :choose_product}} = socket
      ) do
    send(socket.root_pid, {:open_choose_product, photo_id})

    noreply(socket)
  end

  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  def handle_event("prev", _, socket) do
    socket
    |> move_carousel(&CLL.prev/1)
    |> noreply
  end

  def handle_event("next", _, socket) do
    socket
    |> move_carousel(&CLL.next/1)
    |> noreply
  end

  def handle_event("keydown", %{"key" => "ArrowLeft"}, socket),
    do: __MODULE__.handle_event("prev", [], socket)

  def handle_event("keydown", %{"key" => "ArrowRight"}, socket),
    do: __MODULE__.handle_event("next", [], socket)

  def handle_event("keydown", _, socket), do: socket |> noreply

  @impl true
  def handle_event("like", %{"id" => id}, %{assigns: %{from: from}} = socket) do
    {:ok, _} = if from == :photographer, do: Photos.toggle_photographer_liked(id), else: Photos.toggle_liked(id)
    socket |> noreply()
  end

  defp move_carousel(%{assigns: %{photo_ids: photo_ids}} = socket, fun) do
    photo_ids = fun.(photo_ids)
    photo_id = CLL.value(photo_ids)

    socket
    |> assign(photo_ids: photo_ids)
    |> assign_photo(photo_id)
  end

  defp assign_photo(socket, photo_id) do
    socket
    |> assign(:photo, Galleries.get_photo(photo_id))
    |> then(&assign(&1, url: preview_url(&1.assigns.photo, blank: true)))
  end

  @impl true
  def render(%{photo: photo} = assigns) do
    is_liked = if assigns.from == :photographer, do: photo.is_photographer_liked, else: photo.client_liked
    ~H"""
    <div>
      <div class="w-screen h-screen lg:h-full overflow-auto lg:overflow-y-scroll flex lg:justify-between">
        <a phx-click="close" phx-target={@myself} phx-value-photo_id={@photo.id} class="absolute z-50 p-2 rounded-full cursor-pointer right-5 top-5">
          <.icon name="close-x" class="w-6 h-6 text-base-100 stroke-current stroke-2" />
        </a>
        <div class="max-w-5xl choose-product-item  lg:mx-auto mx-2 lg:h-full lg:w-full relative">
          <div id="wrapper" class="flex  h-full w-full md:items-start items-center justify-center">
            <div phx-click="prev" phx-window-keyup="keydown" phx-target={@myself} class="hidden lg:flex left-0 bg-inherit border-2 choose-product__btn top-1/2 -translate-y-1/2 -translate-x-1/4">
              <.icon name="back" class="w-8 h-8 cursor-pointer text-base-100" />
            </div>
            <div phx-click="next" phx-target={@myself} class="hidden lg:flex right-0 bg-inherit choose-product__btn border-2 top-1/2 -translate-y-1/2 translate-x-1/4">
              <.icon name="forth" class="w-8 h-8 cursor-pointer text-base-100" />
            </div>
            <div class="flex flex-col md:items-center justify-center">
              <div class="relative lg:h-[450px] sm:h-screen justify-center">
                <img src={ @url } class="max-h-full sm:object-contain">

                <button class="likeBtn absolute" phx-click={js_like_click(@photo.id, @myself)}>
                  <div id={"photo-#{@photo.id}-liked"} style={!is_liked && "display: none"}>
                    <.icon name="heart-filled" class="text-gray-200 w-7 h-7"/>
                  </div>

                  <div id={"photo-#{@photo.id}-to-like"} style={is_liked && "display: none"}>
                    <.icon name="heart-white" class="text-transparent fill-current w-7 h-7 hover:text-base-200 hover:text-opacity-40"/>
                  </div>
                </button>
              </div>
              <div class="flex mt-2 justify-between gap-1">
                <div phx-click="prev" phx-window-keyup="keydown" phx-target={@myself} class="flex lg:hidden ml-2">
                  <.icon name="back" class="w-10 h-10 cursor-pointer text-base-100 border border-base-100 rounded-full p-2" />
                </div>
                <div class="flex">
                  <span class="text-base-200 font-extrabold text-xl items-center"><%= @photo.name %></span>
                </div>
                <div phx-click="next" phx-target={@myself} class="flex lg:hidden mr-2">
                  <.icon name="forth" class="w-10 h-10 cursor-pointer text-base-100 border border-base-100 rounded-full p-2" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
