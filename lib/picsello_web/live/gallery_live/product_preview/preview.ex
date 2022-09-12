defmodule PicselloWeb.GalleryLive.ProductPreview.Preview do
  @moduledoc "no doc"

  use PicselloWeb, :live_component
  alias Picsello.GalleryProducts

  import PicselloWeb.GalleryLive.Shared, only: [cards_width: 1]

  def update(%{product: product} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(category: product.category, photo: product.preview_photo, product_id: product.id)
    |> ok()
  end

  def handle_event("sell_product_enabled", _, %{assigns: %{product: product}} = socket) do
    socket
    |> assign(product: GalleryProducts.toggle_sell_product_enabled(product))
    |> noreply()
  end

  def handle_event("product_preview_enabled", _, %{assigns: %{product: product}} = socket) do
    socket
    |> assign(product: GalleryProducts.toggle_product_preview_enabled(product))
    |> noreply()
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-between">
      <div class="items-center mt-8">
        <div class={classes("flex items-center pt-4 font-sans lg:text-lg text-2xl font-bold", %{"text-gray-400" => @category.coming_soon})}>
          <%= @category.name %>
        </div>

        <div class=" mx-4 pt-4 flex flex-col justify-between" >

          <label class="inline-flex relative items-center cursor-pointer">
          <input type="checkbox" class="sr-only peer" phx-click="sell_product_enabled" checked={@product.sell_product_enabled} phx-target={@myself}>
          <div class="w-11 h-6 bg-gray-200 rounded-full peer  peer-focus:ring-toggle-100 dark:peer-focus:ring-toggle-300 dark:bg-gray-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-toggle-100"></div>
          <span class="ml-3 text-sm font-medium text-gray-900 dark:text-gray-300">Product enabled to sell</span>
          </label>

        </div>

        <div class={classes("mt-4 pb-4 bg-gray-200", %{"bg-gray-200/20" => @category.coming_soon})}>
        <div class=" mx-4 pt-4 flex flex-col justify-between">

        <%= if @product.sell_product_enabled do %>
        <label class="inline-flex relative items-center cursor-pointer">
          <input type="checkbox" class="sr-only peer" phx-click="product_preview_enabled" checked={@product.product_preview_enabled} phx-target={@myself}>
          <div class="w-11 h-6 bg-gray-300 rounded-full peer  peer-focus:ring-toggle-100 dark:peer-focus:ring-toggle-100 dark:bg-gray-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-toggle-100"></div>
          <span class="ml-3 text-sm font-medium text-gray-900 dark:text-gray-300">Show product preview in gallery</span>
          </label>
        <% end %>
        </div>

          <div class="flex items-center justify-center mt-4">
            <.framed_preview category={@category} photo={@photo} width={cards_width(@category.frame_image)}/>
          </div>

          <div class="flex justify-start pt-4 pl-4">

            <%= if @category.coming_soon do %>
              <button class="text-blue-planning-300 bg-blue-planning-100 rounded-lg font-bold p-2" disabled>
              Coming soon!
              </button>
            <% else %>
            <%= if @product.preview_enabled and @product.enabled do %>
              <button
              class="flex items-center font-sans text-sm py-2 pr-3.5 pl-3 bg-white border border-blue-planning-300 rounded-lg cursor-pointer"
              phx-click="edit"
              id={"product-id-#{@product_id}"}
              phx-value-product_id={@product_id}>
                <.icon name="pencil" class="mr-2.5 w-3 h-3 fill-current text-blue-planning-300" />
                <span>Edit product preview</span>
              </button>
            <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
