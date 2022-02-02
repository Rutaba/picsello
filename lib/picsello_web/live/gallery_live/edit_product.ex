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

  defp assign_whcc_products(%{assigns: %{category_template: template}} = socket) do
    socket
    |> assign(
      :whcc_products,
      GalleryProducts.get_whcc_products(template.category_id)
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
    |> Enum.map(fn option -> [key: option["name"], value: option["id"]] end)
  end

  defp initial_size_option(options) do
    options
    |> List.first()
    |> then(fn option -> option[:key] end)
  end
end
