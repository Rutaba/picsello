defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_gallery_client"]
  alias Picsello.{Cart, Cart.Order, WHCC, Galleries}
  alias PicselloWeb.GalleryLive.ClientMenuComponent
  import PicselloWeb.GalleryLive.Shared
  import Money.Sigils

  import PicselloWeb.Live.Profile.Shared, only: [photographer_logo: 1]

  @impl true
  def mount(_params, _session, %{assigns: %{gallery: gallery}} = socket) do
    case Cart.get_unconfirmed_order(gallery.id, preload: [:products, :digitals, :package]) do
      {:ok, order} ->
        gallery = Galleries.populate_organization_user(gallery)

        socket
        |> assign(gallery: gallery, order: order, client_menu_id: "clientMenu")
        |> assign_cart_count(gallery)

      _ ->
        socket
        |> push_redirect(
          to: Routes.gallery_client_index_path(socket, :index, gallery.client_link_hash)
        )
    end
    |> ok()
  end

  @impl true
  def handle_params(
        _params,
        _uri,
        %{
          assigns: %{
            order: order,
            gallery: %{job: %{client: %{organization: organization}}},
            live_action: :address
          }
        } = socket
      ) do
    socket
    |> assign(
      delivery_info_changeset: Cart.order_delivery_info_change(order),
      organization: organization,
      checking_out: false
    )
    |> noreply()
  end

  def handle_params(_params, _uri, socket), do: noreply(socket)

  @impl true
  def handle_event(
        "checkout",
        _,
        %{
          assigns: %{
            delivery_info_changeset: delivery_info_changeset,
            order: order,
            gallery: gallery
          }
        } = socket
      ) do
    case Cart.store_order_delivery_info(order, Map.put(delivery_info_changeset, :action, nil)) do
      {:ok, order} ->
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
          cancel_url:
            Routes.gallery_client_show_cart_url(socket, :cart, gallery.client_link_hash),
          helpers: PicselloWeb.Helpers
        )
        |> case do
          :ok ->
            socket |> assign(:checking_out, true) |> push_event("scroll:lock", %{})

          _error ->
            socket |> put_flash(:error, "something went wrong")
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
        %{assigns: %{gallery: gallery}} = socket
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
        %{"bundle" => _} -> [bundle: true]
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

  def handle_event("validate_delivery_info", %{"delivery_info" => params}, socket) do
    socket
    |> assign(
      :delivery_info_changeset,
      params |> Cart.delivery_info_change() |> Map.put(:action, :validate)
    )
    |> noreply()
  end

  def handle_event(
        "place_changed",
        params,
        %{assigns: %{delivery_info_changeset: changeset}} = socket
      ) do
    socket
    |> assign(delivery_info_changeset: Cart.delivery_info_change(changeset, params))
    |> noreply()
  end

  @impl true
  @doc "called when checkout completes"
  def handle_info(
        {:checkout, :complete, %Order{} = order},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> push_redirect(
      to:
        Routes.gallery_client_order_path(
          socket,
          :show,
          gallery.client_link_hash,
          Order.number(order)
        ),
      replace: true
    )
    |> push_event("scroll:unlock", %{})
    |> noreply()
  end

  @impl true
  def handle_info({:checkout, :due, stripe_url}, socket) do
    socket |> redirect(external: stripe_url) |> noreply()
  end

  def handle_info({:checkout, :error, _error}, socket) do
    socket
    |> put_flash(:error, "something went wrong")
    |> assign(:checking_out, false)
    |> push_event("scroll:unlock", %{})
    |> noreply()
  end

  defp continue_summary(assigns) do
    ~H"""
    <.summary order={@order} id={@id}>
      <%= live_patch to: Routes.gallery_client_show_cart_path(@socket, :address, @order.gallery.client_link_hash), class: "mx-5 text-lg mb-7 btn-primary text-center" do %>
        Continue
      <% end %>
    </.summary>
    """
  end

  defp only_digitals?(%{products: []} = order), do: digitals?(order)
  defp only_digitals?(%{products: [_ | _]}), do: false
  defp digitals?(%{digitals: [_ | _]}), do: true
  defp digitals?(%{digitals: [], bundle_price: %Money{}}), do: true
  defp digitals?(_), do: false
  defp show_cart?(:cart), do: true
  defp show_cart?(_), do: false

  defp item_id(item), do: item.editor_id

  defdelegate cart_count(order), to: Cart, as: :item_count
  defdelegate lines_by_product(order), to: Cart
  defdelegate product_quantity(product), to: Cart
  defdelegate summary(assigns), to: __MODULE__.Summary

  defp zero_total?(order),
    do: order |> Cart.total_cost() |> Money.zero?()
end
