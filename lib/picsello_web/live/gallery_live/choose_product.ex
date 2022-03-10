defmodule PicselloWeb.GalleryLive.ChooseProduct do
  @moduledoc "no doc"
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared, only: [button: 1]
  alias Picsello.{Galleries, GalleryProducts}

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id} = assigns, socket) do
    photo = Galleries.get_photo(photo_id)

    socket
    |> assign(Map.drop(assigns, [:gallery, :photo_id]))
    |> assign(
      download_each_price: Galleries.download_each_price(gallery),
      gallery_id: gallery.id,
      photo: photo,
      products: GalleryProducts.get_gallery_products(gallery.id)
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
        %{assigns: %{photo: photo, download_each_price: price}} = socket
      ) do
    send(
      socket.root_pid,
      {:add_digital_to_cart,
       %Picsello.Cart.Order.Digital{
         photo_id: photo.id,
         preview_url: photo.preview_url,
         price: price
       }}
    )

    socket |> noreply()
  end

  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  defp url(photo), do: path(photo.watermarked_preview_url || photo.preview_url)

  defp option(assigns) do
    assigns = Enum.into(assigns, %{min_price: nil})

    ~H"""
    <div {testid("product_option_#{@testid}")} class="p-5 xl:p-7 border border-base-225 rounded mb-4 lg:mb-7">
      <div class="flex justify-between items-center">
        <div class="flex flex-col mr-2">
          <p class="font-semibold text-lg text-base-300"><%= @title %></p>

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

  defp move_carousel(%{assigns: %{gallery_id: gallery_id, photo_ids: photo_ids}} = socket, fun) do
    photo_ids = fun.(photo_ids)
    photo_id = CLL.value(photo_ids)

    assign(socket,
      photo: Galleries.get_photo(photo_id),
      photo_ids: photo_ids,
      digital_in_cart: Picsello.Cart.contains_digital?(gallery_id, photo_id)
    )
  end

  defdelegate min_price(category), to: Picsello.WHCC
end
