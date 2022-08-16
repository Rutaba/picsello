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
        <div class="flex my-2">
          <div {testid("selection-name")} class="flex items-center z-10 text-base-250">Client Selection - <%= DateTime.to_date(order.placed_at) %></div>
          <div id={"meatball-order-#{order.id}"} data-offset-y="0" data-offset-x="0" phx-hook="Select" class="ml-auto items-center flex">
            <button class="sticky">
              <.icon name="meatballs" class="w-4 h-4 text-base-225 stroke-current stroke-2 opacity-100 open-icon" />
              <.icon name="close-x" class="hidden w-3 h-3 text-base-225 stroke-current stroke-2 close-icon opacity-100"/>
            </button>
            <ul class="absolute hidden bg-white rounded-md popover-content meatballsdropdown w-40 overflow-visible cursor-pointer">
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
              <li class="flex items-center pl-1 py-1 hover:bg-blue-planning-100 hover:rounded-md">
                <a href={Routes.gallery_downloads_url(
                          @socket,
                          :download_csv,
                          @gallery.client_link_hash,
                          order.number)}
                  class="hover-drop-down"
                  target="_blank"
                  rel="noopener noreferrer">
                  Download as .CSV
                </a>
              </li>
            </ul>
          </div>
        </div>

        <hr class="sticky my-2 border-base-225">

        <div class="grid gap-2 lg:grid-cols-4 md:grid-cols-3 sm:grid-cols-1">
          <%= for digital <- order.digitals do%>
            <div class="sticky w-[200px] h-[130px] bg-gray-200 cursor-pointer hover:opacity-80" phx-click={toggle_border(digital.photo.id)} phx-click-away={JS.remove_class("item-border", to: "item-#{digital.photo.id}")} id={"item-#{digital.photo.id}"}>
              <div class="h-full relative" id={"photo-#{digital.photo.id}"} phx-click="toggle_selected_photos" phx-value-photo_id={digital.photo.id} phx-hook="GallerySelector">
                  <div id={"photo-#{digital.photo.id}-selected"} photo-id={digital.photo.id} class="toggle-it"></div>
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

  def toggle_border(js \\ %JS{}, id) do
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
