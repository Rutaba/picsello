defmodule PicselloWeb.GalleryLive.EditProduct do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.WHCC

  @impl true
  def mount(socket) do
    socket
    |> assign(:type, :print)
    |> assign_whcc_product()
    |> assign_whcc_product_size()
    |> ok()
  end

  @impl true
  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_event("update-print-type", %{"product-name" => product_name}, socket) do
    socket
    |> assign_whcc_product(product_name)
    |> assign_whcc_product_size()
    |> noreply()
  end

  def handle_event("update-print-type", _params, socket) do
    socket |> noreply()
  end

  def handle_event("update-product-size", %{"product_size" => %{"option" => size}}, socket) do
    socket
    |> assign_whcc_product_size(size)
    |> noreply()
  end

  def title_by_type(:print), do: "Prints"
  def title_by_type(:framed_print), do: "Framed prints"
  def title_by_type(:album), do: "Custom album"

  defp assign_whcc_product(%{assigns: %{type: :print}} = socket) do
    products = WHCC.print_products()

    socket
    |> assign(:print_products, products)
    |> assign(:whcc_product, List.first(products))
  end

  defp assign_whcc_product(%{assigns: %{type: :framed_print}} = socket) do
    socket
    |> assign(:whcc_product, WHCC.framed_print_product())
  end

  defp assign_whcc_product(%{assigns: %{type: :album}} = socket) do
    socket
    |> assign(:whcc_product, WHCC.framed_print_product())
  end

  defp assign_whcc_product(%{assigns: %{print_products: products, type: :print}} = socket, name) do
    socket
    |> assign(:whcc_product, Enum.find(products, fn product -> product.whcc_name == name end))
  end

  defp assign_whcc_product_size(%{assigns: %{whcc_product: product}} = socket) do
    socket
    |> assign(:whcc_product_size, product |> product_size_options() |> initial_size_option())
  end

  defp assign_whcc_product_size(socket, size) do
    socket
    |> assign(:whcc_product_size, size)
  end

  defp product_size_options(product) do
    product.attribute_categories
    |> Enum.find(fn category -> category["_id"] == "size" end)
    |> then(fn %{"attributes" => attributes} -> attributes end)
    |> Enum.map(fn option -> [key: option["id"], value: option["name"]] end)
  end

  defp initial_size_option(options) do
    options
    |> List.first()
    |> then(fn option -> option[:key] end)
  end
end
