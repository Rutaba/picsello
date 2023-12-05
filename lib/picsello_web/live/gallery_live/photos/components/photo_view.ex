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
    |> assign(assigns)
    |> assign_photo(photo_id)
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
    {:ok, _} =
      if from == :photographer,
        do: Photos.toggle_photographer_liked(id),
        else: Photos.toggle_liked(id)

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
    |> then(
      &assign(&1,
        url:
          preview_url(&1.assigns.photo,
            proofing_client_view?: &1.assigns.is_proofing,
            blank: true
          )
      )
    )
  end

  @impl true
  def render(%{photo: photo} = assigns) do
    is_liked =
      if assigns.from == :photographer, do: photo.is_photographer_liked, else: photo.client_liked

    assigns = assign(assigns, :is_liked, is_liked)

    ~H"""
    <div>
      <div class="w-screen h-screen lg:h-full overflow-auto flex lg:justify-between">
        <a phx-click="close" phx-target={@myself} phx-value-photo_id={@photo.id} class="absolute z-50 p-2 rounded-full cursor-pointer right-5 top-5">
          <.icon name="close-x" class="w-6 h-6 text-base-100 stroke-current stroke-2" />
        </a>
        <div class="relative justify-center flex flex-col h-screen w-screen p2 md:p-5">
          <img src={preview_url(@photo, proofing_client_view?: @is_proofing)} class="object-contain h-full flex-shrink-1 p2 md:p-5" loading="lazy">
          <div class="flex gap-4 md:gap-10 flex-grow-1 w-full justify-between md:justify-center md:pb-4 pb-16 px-8 md:px-0">
            <div phx-click="prev" phx-window-keyup="keydown" phx-target={@myself} class="bg-inherit border-2 flex items-center justify-center w-10 h-10 rounded-full flex-shrink-0">
              <.icon name="back" class="w-full h-full p-2 cursor-pointer text-base-100 stroke-2" />
            </div>
            <div class="flex items-center gap-2">
              <%= if !@is_proofing do %>
                <button class="likeBtn" phx-click={js_like_click(@photo.id, @myself)}>
                  <div id={"photo-#{@photo.id}-liked"} style={!@is_liked && "display: none"}>
                    <.icon name="heart-filled" class="text-gray-200 w-7 h-7"/>
                  </div>
                  <div id={"photo-#{@photo.id}-to-like"} style={@is_liked && "display: none"}>
                    <.icon name="heart-white" class="text-transparent fill-current w-7 h-7 hover:text-base-200 hover:text-opacity-40"/>
                  </div>
                </button>
              <% end %>
              <h4 class="text-base-200 font-light text-sm items-center flex-shrink-0 truncate sm:max-w-none max-w-[120px] underline sm:no-underline cursor-pointer" {testid("lightbox-photo-name")} phx-hook="Tooltip" id="filename" data-hint={@photo.name}>
                <%= @photo.name %>
              </h4>
            </div>
            <div phx-click="next" phx-target={@myself} class="bg-inherit border-2 flex items-center justify-center w-10 h-10 rounded-full flex-shrink-0">
              <.icon name="forth" class="w-full h-full p-2 cursor-pointer text-base-100 stroke-2" />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
