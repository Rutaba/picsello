defmodule PicselloWeb.GalleryLive.ProductPreview.Preview do
  @moduledoc "no doc"

  use PicselloWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-between">
      <div class="items-center mt-8">
        <div class="flex items-center pt-4 font-sans text-lg font-bold">
          <%= @category.name %>
        </div>

        <div class="mt-4 pb-14 bg-base-200">
          <div class="flex justify-start pt-4 pl-4">
            <button
              class="flex items-center font-sans text-sm py-2 pr-3.5 pl-3 bg-white border border-blue-planning-300 rounded-lg cursor-pointer"
              phx-click="edit"
              phx-value-product_id={@product_id}>
                <.icon name="pencil" class="mr-2.5 w-3 h-3 fill-current text-blue-planning-300" />

                <span>Edit this</span>
            </button>
          </div>

          <div class="flex items-center justify-center mt-4"><.framed_preview category={@category} photo={@photo}/></div>
        </div>
      </div>
    </div>
    """
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
