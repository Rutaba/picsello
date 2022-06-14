defmodule PicselloWeb.GalleryLive.ChooseProduct do
  @moduledoc "no doc"
  use PicselloWeb, :live_component
  alias Picsello.{Cart, Galleries, GalleryProducts}
  alias Cart.Digital
  import PicselloWeb.GalleryLive.Shared, only: [credits_footer: 1, credits: 1]

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_details(Galleries.get_photo(photo_id))
    |> assign(
      download_each_price: Galleries.download_each_price(gallery),
      products: GalleryProducts.get_gallery_products(gallery.id, :coming_soon_false)
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
      {:add_digital_to_cart, %Digital{photo: photo, price: price}}
    )

    socket |> noreply()
  end

  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  defp move_carousel(%{assigns: %{photo_ids: photo_ids}} = socket, fun) do
    photo_ids = fun.(photo_ids)

    socket
    |> assign(photo_ids: photo_ids)
    |> assign_details(photo_ids |> CLL.value() |> Galleries.get_photo())
  end

  defp assign_details(%{assigns: %{gallery: gallery}} = socket, photo) do
    %{digital: digital_credit} = credits = Cart.credit_remaining(gallery)

    socket
    |> assign(
      digital_status: Cart.digital_status(gallery, photo),
      digital_credit: digital_credit,
      photo: photo,
      credits: credits(credits)
    )
  end

  defdelegate option(assigns), to: PicselloWeb.GalleryLive.Shared, as: :product_option
  defdelegate min_price(category), to: Galleries
end
