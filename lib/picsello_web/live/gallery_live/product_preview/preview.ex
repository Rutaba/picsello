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
        <div>

          <label class="items-center cursor-pointer mt-4 switch" id="toggleSwitch" >
           <div class=" ml-3">
              <input id="toggle" type="checkbox" phx-click="" checked>
              <span class="slider round toggle-switch-handle" data-label-off="Product disabled" data-label-on="Product enabled"></span>
            </div>
            </label>
            <div class="text-sm lg:text-xl text-base-250">Product enabled</div>
        </div>

        <div class={classes("mt-4 pb-14 bg-gray-200", %{"bg-gray-200/20" => @category.coming_soon})}>

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
                <span>Edit this</span>
              </button>
            <% end %>
          </div>

          <div class="flex items-center justify-center mt-4">
            <.framed_preview category={@category} photo={@photo} width={cards_width(@category.frame_image)}/>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
