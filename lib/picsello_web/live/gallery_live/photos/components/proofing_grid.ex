defmodule PicselloWeb.GalleryLive.Photos.ProofingGrid do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="md:mt-0 md:mb-0 mt-16 mb-6">
      <%= for order <- @orders do%>
        <hr class="sticky my-2 border-base-300/10">
        <div class="flex my-2">
          <div {testid("selection-name")} class="flex items-center z-10 text-blue-planning-300 font-bold">Client Selection - <%= DateTime.to_date(order.placed_at) %></div>
          <div id={"meatball-order-#{order.id}"} data-offset-y="0" data-offset-x="0" phx-hook="Select" class="ml-auto items-center flex">
            <button {testid("actions")} class="sticky flex items-center px-2 py-2 font-sans rounded-lg hover:opacity-75 text-sm ml-2.5 bg-white shadow-lg lg:my-0 gap-2 text-blue-planning-300">
              Actions
              <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
              <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
            </button>
            <ul class="z-10 flex flex-col hidden w-44 bg-white border rounded-lg shadow-lg popover-content">
              <li class="flex items-center pl-1 py-1 hover:bg-blue-planning-100 hover:rounded-md">
                <a href={Routes.gallery_downloads_url(
                          @socket,
                          :download_lightroom_csv,
                          @gallery.client_link_hash,
                          order.number)}
                  class="hover-drop-down "
                  target="_blank"
                  rel="noopener noreferrer">
                  Download file names
                </a>
              </li>
              <li class="flex items-center pl-1 py-1 hover:bg-blue-planning-100 hover:rounded-md">
                <a class="hover-drop-down"
                  download
                  href={Routes.gallery_downloads_path(
                        @socket,
                        :download_all,
                        @gallery.client_link_hash,
                        photo_ids: Enum.map(order.digitals, fn digital -> digital.photo.id end) |> Enum.join(",")
                        )}>
                  Download photos
                </a>
              </li>
            </ul>
          </div>
        </div>

        <hr class="sticky my-2 border-base-300/10">

        <div class="grid gap-2.5 md:justify-start justify-center mt-4" style="grid-template-columns: repeat(auto-fill, minmax(0px, 200px));">
          <%= for digital <- order.digitals do%>
            <div class="sticky w-[200px] h-[130px] bg-gray-200 cursor-pointer hover:opacity-80" phx-click={toggle_border(digital.photo.id)} phx-click-away={JS.remove_class("item-border", to: "item-#{digital.photo.id}")} id={"selected-item-#{digital.photo.id}"}>
              <div {testid("proofing-grid-item")} class="h-full relative toggle-parent" id={"selected-photo-#{digital.photo.id}"} phx-click="toggle_selected_photos" phx-value-photo_id={digital.photo.id}>
                  <div id={"photo-#{digital.photo.id}-selected"} photo-id={digital.photo.id} class="toggle"></div>
                  <img src={preview_url(digital.photo)}class="w-full h-full object-contain relative" />
                  <.icon name="star" class="absolute opacity-100 right-3 bottom-2 text-white w-5 h-5"/>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp toggle_border(js \\ %JS{}, id) do
    js
    |> JS.dispatch("click", to: "#photo-#{id} > img")
    |> JS.add_class("item-border", to: "#item-#{id}")
  end

  def proofing_grid(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id] || "proofing-grid"} {assigns} />
    """
  end
end
