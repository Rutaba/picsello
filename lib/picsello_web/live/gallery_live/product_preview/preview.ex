defmodule PicselloWeb.GalleryLive.ProductPreview.Preview do
  @moduledoc "no doc"

  use PicselloWeb, :live_component

  import PicselloWeb.GalleryLive.Shared, only: [cards_width: 1]

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-between">
      <div class="items-center mt-8">
        <div class={classes("flex items-center pt-4 font-sans lg:text-lg text-2xl font-bold", %{"text-gray-400" => @category.coming_soon})}>
          <%= @category.name %>

        </div>
        <div class=" mx-4 pt-4 flex flex-col justify-between" >
          <label class="toggle">
            <input class="toggle-checkbox" type="checkbox" phx-click="" checked>
            <div class="toggle-switch"></div>
            <span class="toggle-label">Product Enabled</span>
          </label>
        </div>


        <div class={classes("mt-4 pb-4 bg-gray-200", %{"bg-gray-200/20" => @category.coming_soon})}>
        <div class=" mx-4 pt-4 flex flex-col justify-between">
        <label class="toggle">
          <input class="toggle-checkbox" type="checkbox" phx-click="" checked>
          <div class="toggle-switch"></div>
          <span class="toggle-label">Show product preview in gallery</span>
        </label>
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

              <button
              class="flex items-center font-sans text-sm py-2 pr-3.5 pl-3 bg-white border border-blue-planning-300 rounded-lg cursor-pointer"
              id={"product-id-#{@product_id}"}
              phx-click="edit"
              phx-value-product_id={@product_id}>
                <.icon name="pencil" class="mr-2.5 w-3 h-3 fill-current text-blue-planning-300" />
                <span>Edit product preview</span>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
