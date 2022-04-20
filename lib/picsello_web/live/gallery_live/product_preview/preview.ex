defmodule PicselloWeb.GalleryLive.ProductPreview.Preview do
  @moduledoc "no doc"

  use PicselloWeb, :live_component

  alias Picsello.{Photos, Category}

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> set_preview()
    |> ok
  end

  defp set_preview(%{assigns: %{category: category, photo: nil}} = socket) do
    socket
    |> push_event(
      "set_preview",
      category
      |> to_event_args()
      |> Map.merge(%{
        preview: Photos.preview_url(nil, blank: true),
        width: nil,
        height: nil
      })
    )
  end

  defp set_preview(%{assigns: %{category: category, photo: photo}} = socket) do
    socket
    |> push_event(
      "set_preview",
      category
      |> to_event_args()
      |> Map.merge(%{
        preview: Photos.preview_url(photo, blank: true),
        ratio: photo.aspect_ratio
      })
    )
  end

  defp to_event_args(category),
    do: %{
      frame: Category.frame_image(category),
      coords: Category.coords(category),
      target: category.id
    }

  def render(assigns) do
    ~H"""
    <div id={"photo#{@photo && @photo.id}"} class="flex flex-col justify-between" phx-hook="Preview">
      <div class="items-center mt-8">
        <div class="font-sans text-lg font-bold pt-4 flex items-center">
        <%= @category.name %>
        </div>
        <div class= "product-container mt-4">
          <div class="flex justify-start pt-4 pl-4">
                <div
                class="flex items-center font-sans text-sm py-2 pr-3.5 pl-3 bg-white border border-blue-planning-300 rounded-lg cursor-pointer"
                phx-click="edit"
                phx-value-product_id={@product_id}
                id={"productId#{@product_id}"}>
                  <.icon name="pencil" class="mr-2.5 w-3 h-3 fill-current text-blue-planning-300" />
                  <span>Edit this</span>
                </div>
          </div>
          <div class="product-rect p-6 flex justify-center items-center">
            <canvas id={"canvas-#{@category.id}"} width="300" height="255" class="bg-gray-300"></canvas>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
