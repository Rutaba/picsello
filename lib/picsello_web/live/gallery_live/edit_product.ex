defmodule PicselloWeb.GalleryLive.EditProduct do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.GalleryProducts

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_whcc_products()
    |> set_current_whcc_product()
    |> set_whcc_product_size()
    |> ok()
  end

  @impl true
  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_event("update-print-type", %{"product-id" => id}, socket) do
    socket
    |> set_current_whcc_product(String.to_integer(id))
    |> set_whcc_product_size()
    |> push_event("update_print_type", %{})
    |> noreply()
  end

  def handle_event("update-print-type", _params, socket) do
    socket |> noreply()
  end

  def handle_event("update-product-size", %{"product_size" => %{"option" => size}}, socket) do
    socket
    |> set_whcc_product_size(size)
    |> noreply()
  end

  def handle_event(
        "customize_and_buy",
        _,
        %{assigns: %{current_whcc_product: whcc_product, photo: photo, whcc_product_size: size}} =
          socket
      ) do
    send(self(), {:customize_and_buy_product, whcc_product, photo, size})

    socket |> noreply()
  end

  defp assign_whcc_products(%{assigns: %{category: category}} = socket) do
    socket
    |> assign(
      :whcc_products,
      GalleryProducts.get_whcc_products(category.id)
    )
  end

  defp set_current_whcc_product(%{assigns: %{whcc_products: whcc_products}} = socket) do
    socket
    |> assign(:current_whcc_product, List.first(whcc_products))
  end

  defp set_current_whcc_product(%{assigns: %{whcc_products: whcc_products}} = socket, id) do
    socket
    |> assign(:current_whcc_product, Enum.find(whcc_products, fn product -> product.id == id end))
  end

  defp set_whcc_product_size(%{assigns: %{current_whcc_product: product}} = socket) do
    socket
    |> assign(:whcc_product_size, product |> product_size_options() |> initial_size_option())
  end

  defp set_whcc_product_size(socket, size) do
    socket
    |> assign(:whcc_product_size, size)
  end

  defp product_size_options(%{sizes: sizes}) do
    sizes
    |> Enum.map(&{Map.get(&1, "name"), Map.get(&1, "id")})
  end

  defp initial_size_option(options) do
    options
    |> List.first()
    |> elem(1)
  end

  def product_description(%{api: %{"_id" => id}}) do
    %{
      "aeAXpFbKeRbvzGxxs" =>
        "Archival loose or mounted inkjet prints to showcase both artwork and photography.",
      "BBrgfCJLkGzseCdds" =>
        "Professional quality photo prints with multiple finish and mounting options.",
      "DkCRPMJEWy9yieTEo" =>
        "Beautifully handcrafted canvas artwork that makes a statement in any setting.",
      "drm8DGr5Nd6NW8m3x" =>
        "Our Woodland collection is made in the USA and designed to reveal the true beauty of American hardwoods.",
      "fY596j4wC5syHKnyF" => "Distressed Frames have a brushed, distressed finish.",
      "f5QQgHg9mAEom37bQ" =>
        "Let your moments shine through crystal clear acrylic with exceptional detail reproduction.",
      "8xo9ktcm4i3XL7u66" =>
        "Printed on high-quality aluminum for an impressive display that stands the test of time.",
      "R8vHegM2bgiYSgkDJ" =>
        "Sleek, lightweight display with multiple edge styles to accent your imagery.",
      "RrKCwu4G4kdQXiXum" =>
        "Go modern with a Gallery Frame. These frames speak for themselves by adding a clean, crisp look to any setting.",
      "ikNaYPvMQ3BAE5d8s" =>
        "Ashland Frames bring character and warmth into the home. Ashland has a flat surface moulding with brushed finish."
    }
    |> Map.get(id)
  end

  def product_description(_), do: ""

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
