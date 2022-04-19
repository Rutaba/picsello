defmodule PicselloWeb.GalleryLive.ChooseBundle do
  @moduledoc "product info modal for digital bundle"
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared, only: [bundle_image: 1]
  alias Picsello.{Cart, Galleries}
  import Cart, only: [item_image_url: 1]

  def update(%{gallery: gallery} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(
      bundle_status: Cart.bundle_status(gallery),
      download_all_price: Galleries.get_package(gallery).buy_all,
      gallery: gallery
    )
    |> ok()
  end

  def render(assigns) do
    ~H"""
    <div class="choose-product__modal bg-base-100">
      <a href="#" phx-click="close" title="close" phx-target={@myself} class="absolute cursor-pointer right-5 top-5">
        <.icon name="close-x" class="w-4 h-4 stroke-current lg:w-5 lg:h-5 stroke-2" />
      </a>

      <p class="px-5 pt-10 pb-5 text-2xl font-bold text-base-300 lg:hidden">Select an option below</p>

      <div class="flex-row w-full px-5 select-none grid lg:flex lg:h-full lg:overflow-y-auto lg:justify-between lg:px-0 lg:pl-16 xl:pl-20">
        <div class="relative w-full p-10 mb-5 choose-product-item h-96 lg:h-full lg:w-7/12 lg:mb-0">
          <.bundle_image url={item_image_url({:bundle, @gallery})} />
        </div>

        <div class="relative choose-product-item lg:w-5/12">
          <div class="flex flex-col ml-auto lg:w-11/12">
            <p class="hidden mb-6 text-2xl font-bold text-base-300 lg:pt-2 lg:block">Bundle - all digital downloads</p>

            <%= case @bundle_status do %>
              <% :in_cart -> %>
                <.option testid={"bundle_download"} title="All digital downloads">
                  <:button disabled>In cart</:button>
                </.option>
              <% :purchased -> %>
                <.option testid={"bundle_download"} title="All digital downloads">
                  <:button disabled>Purchased</:button>
                </.option>
              <% _ -> %>
                <.option testid={"bundle_download"} title="All digital downloads" min_price={@download_all_price}>
                  <:button phx-target={@myself} phx-click="bundle_add_to_cart">
                    Add to cart
                  </:button>
                </.option>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  def handle_event("bundle_add_to_cart", %{}, %{assigns: %{download_all_price: price}} = socket) do
    send(socket.root_pid, {:add_bundle_to_cart, price})

    socket |> noreply()
  end

  defdelegate option(assigns), to: PicselloWeb.GalleryLive.Shared, as: :product_option
end
