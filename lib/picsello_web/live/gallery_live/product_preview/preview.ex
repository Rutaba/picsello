defmodule PicselloWeb.GalleryLive.ProductPreview.Preview do
  @moduledoc "no doc"

  use PicselloWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-between">
      <div class="items-center mt-8">
        <div class={classes("flex items-center pt-4 font-sans text-lg font-bold", %{"text-gray-400" => @category.coming_soon == true})}>
          <%= @category.name %>
        </div>
        <div class={classes("mt-4 pb-14 bg-gray-200", %{"bg-gray-200/20" => @category.coming_soon == true})}>

          <div class="flex justify-start pt-4 pl-4">
            <%= if @category.coming_soon == true do %>
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
            <.framed_preview category={@category} photo={@photo} width={if @category.id == 1, do: "198", else: "300"}/>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
