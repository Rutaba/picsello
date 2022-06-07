defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.{Cart, Cart.Order, WHCC, Galleries}
  alias PicselloWeb.GalleryLive.ClientMenuComponent
  import PicselloWeb.GalleryLive.Shared
  import Money.Sigils

  @impl true
  def mount(_params, _session, %{assigns: %{gallery: gallery}} = socket) do
    case Cart.get_unconfirmed_order(gallery.id, preload: [:products, :digitals, :package]) do
      {:ok, order} ->
        gallery = Galleries.populate_organization_user(gallery)

        socket
        |> assign(:gallery, gallery)
        |> assign(:order, order)
        |> assign(:step, :product_list)
        |> assign_cart_count(gallery)
        |> assign(:client_menu_id, "clientMenu")
        |> ok()

      _ ->
        socket
        |> push_redirect(
          to: Routes.gallery_client_index_path(socket, :index, gallery.client_link_hash)
        )
        |> ok()
    end
  end

  @impl true
  def handle_event("continue", _, %{assigns: %{step: :product_list, order: order}} = socket) do
    socket
    |> assign(:step, :delivery_info)
    |> assign(:delivery_info_changeset, Cart.order_delivery_info_change(order))
    |> noreply()
  end

  def handle_event(
        "checkout",
        _,
        %{
          assigns: %{
            step: :delivery_info,
            delivery_info_changeset: delivery_info_changeset,
            order: order
          }
        } = socket
      ) do
    case Cart.store_order_delivery_info(order, delivery_info_changeset) do
      {:ok, %{gallery: gallery} = order} ->
        order
        |> Cart.checkout(
          success_url:
            Enum.join(
              [
                Routes.gallery_client_order_url(
                  socket,
                  :paid,
                  gallery.client_link_hash,
                  Order.number(order)
                ),
                "session_id={CHECKOUT_SESSION_ID}"
              ],
              "?"
            ),
          cancel_url: Routes.gallery_client_show_cart_url(socket, :cart, gallery.client_link_hash)
        )
        |> case do
          :ok -> socket
          _error -> socket |> put_flash(:error, "something wen't wrong")
        end
        |> noreply()

      {:error, changeset} ->
        socket
        |> assign(:delivery_info_changeset, changeset)
        |> noreply()
    end
  end

  def handle_event(
        "edit_product",
        %{"editor-id" => editor_id},
        %{assigns: %{step: :product_list, gallery: gallery}} = socket
      ) do
    %{url: url} =
      gallery
      |> Galleries.account_id()
      |> WHCC.get_existing_editor(editor_id)

    socket
    |> redirect(external: url)
    |> noreply()
  end

  def handle_event(
        "delete",
        params,
        %{
          assigns: %{
            step: :product_list,
            order: order,
            gallery: gallery,
            client_menu_id: client_menu_id,
            cart_count: count
          }
        } = socket
      ) do
    item =
      case params do
        %{"editor-id" => editor_id} -> [editor_id: editor_id]
        %{"digital-id" => digital_id} -> [digital_id: String.to_integer(digital_id)]
        %{"bundle" => _} -> :bundle
      end

    case Cart.delete_product(order, item) do
      {:deleted, _} ->
        socket
        |> push_redirect(
          to: Routes.gallery_client_index_path(socket, :index, gallery.client_link_hash)
        )
        |> noreply()

      {:loaded, order} ->
        send_update(ClientMenuComponent, id: client_menu_id, cart_count: count - 1)

        socket
        |> assign(:order, order)
        |> noreply()
    end
  end

  def handle_event(
        "validate_delivery_info",
        %{"delivery_info" => params},
        %{assigns: %{step: :delivery_info}} = socket
      ) do
    socket
    |> assign(:delivery_info_changeset, Cart.delivery_info_change(params))
    |> noreply()
  end

  @impl true
  @doc "called when checkout completes"
  def handle_info(
        {:checkout, :complete, %Order{} = order},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> redirect(
      to:
        Routes.gallery_client_order_path(
          socket,
          :show,
          gallery.client_link_hash,
          Order.number(order)
        )
    )
    |> noreply()
  end

  @impl true
  def handle_info({:checkout, :due, stripe_url}, socket) do
    socket |> redirect(external: stripe_url) |> noreply()
  end

  defp continue_summary(assigns) do
    ~H"""
    <.summary order={@order} id={@id}>
      <button type="button" phx-click="continue" class="mx-5 text-lg mb-7 btn-primary">
        Continue
      </button>
    </.summary>
    """
  end

  defp only_digitals?(%{products: []} = order), do: digitals?(order)
  defp only_digitals?(%{products: [_ | _]}), do: false
  defp digitals?(%{digitals: [_ | _]}), do: true
  defp digitals?(%{digitals: [], bundle_price: %Money{}}), do: true
  defp digitals?(_), do: false
  defp show_cart?(:product_list), do: true
  defp show_cart?(_), do: false

  defp item_id(item), do: item.editor_id

  defdelegate cart_count(order), to: Cart, as: :item_count
  defdelegate item_image_url(item), to: Cart
  defdelegate lines_by_product(order), to: Cart
  defdelegate product_name(product), to: Cart
  defdelegate product_quantity(product), to: Cart
  defdelegate summary(assigns), to: __MODULE__.Summary

  defp zero_total?(order),
    do: order |> Cart.total_cost() |> Money.zero?()
end
