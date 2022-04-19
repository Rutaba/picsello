defmodule PicselloWeb.GalleryLive.ChooseProduct do
  @moduledoc "no doc"
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared, only: [button: 1]
  alias Picsello.{Cart, Galleries, GalleryProducts}
  alias Cart.Digital

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id} = assigns, socket) do
    photo = Galleries.get_photo(photo_id)

    socket
    |> assign(assigns)
    |> assign(
      download_each_price: Galleries.download_each_price(gallery),
      photo: photo,
      products: GalleryProducts.get_gallery_products(gallery.id),
      digital_status: Cart.digital_status(gallery, photo),
      digital_credit: Cart.digital_credit(gallery)
    )
    |> ok()
  end

  @impl true
  def handle_event("prev", _, socket) do
    socket
    |> move_carousel(&CLL.prev/1)
    |> noreply
  end

  @impl true
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

  def handle_event(
        "digital_add_to_cart",
        %{},
        %{assigns: %{photo: photo, download_each_price: price, gallery: gallery}} = socket
      ) do
    price = if Cart.digital_credit(gallery) > 0, do: 0, else: price

    send(
      socket.root_pid,
      {:add_digital_to_cart, %Digital{photo: photo, price: price}}
    )

    socket |> noreply()
  end

  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  defp option(assigns) do
    assigns = Enum.into(assigns, %{min_price: nil})

    ~H"""
    <div {testid("product_option_#{@testid}")} class="p-5 mb-4 border rounded xl:p-7 border-base-225 lg:mb-7">
      <div class="flex items-center justify-between">
        <div class="flex flex-col mr-2">
          <p class="text-lg font-semibold text-base-300"><%= @title %></p>

          <%= if @min_price do %>
            <p class="font-semibold text-base text-base-300 pt-1.5 text-opacity-60"> <%= @min_price %></p>
          <% end %>
        </div>

        <%= for button <- @button do %>
          <.button {button}><%= render_slot(button) %></.button>
        <% end %>
      </div>
    </div>
    """
  end

  defp move_carousel(%{assigns: %{gallery: gallery, photo_ids: photo_ids}} = socket, fun) do
    photo_ids = fun.(photo_ids)
    photo = photo_ids |> CLL.value() |> Galleries.get_photo()

    assign(socket,
      photo: photo,
      photo_ids: photo_ids,
      digital_status: Cart.digital_status(gallery, photo),
      digital_credit: Cart.digital_credit(gallery)
    )
  end

  defdelegate min_price(category), to: Picsello.WHCC
end
