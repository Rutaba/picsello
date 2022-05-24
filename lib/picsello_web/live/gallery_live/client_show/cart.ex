defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.{Cart, Payments, WHCC, Galleries}
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
    socket
    |> assign(order: Cart.store_order_delivery_info(order, delivery_info_changeset))
    |> case do
      %{assigns: %{order: %{products: []}}} = socket ->
        redirect(socket, external: checkout_link(socket))

      socket ->
        socket
        |> assign(:ordering_task, nil)
        |> schedule_products_ordering()
    end
    |> noreply()
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
  @doc "called when Task.async completes"
  def handle_info({_ref, order}, %{assigns: %{ordering_task: task}} = socket) do
    Task.shutdown(task, :brutal_kill)

    socket
    |> assign(order: order, ordering_task: nil)
    |> redirect(external: checkout_link(socket))
    |> noreply()
  end

  defp continue_summary(assigns) do
    ~H"""
    <.summary order={@order} id={@id}>
      <button type="button" disabled={zero_subtotal?(@order)} phx-click="continue" class="mx-5 mt-5 text-lg mb-7 btn-primary">
        Continue
      </button>

      <%= if zero_subtotal?(@order) do %>
        <em class="block pt-1 text-xs text-center">Minimum amount is $1</em>
      <% end %>
    </.summary>
    """
  end

  defp checkout_link(%{assigns: %{order: order, gallery: gallery}} = socket) do
    {:ok, checkout_link} =
      order
      |> Cart.checkout_params()
      |> Enum.into(%{
        success_url:
          Enum.join(
            [
              Routes.gallery_client_order_url(
                socket,
                :paid,
                gallery.client_link_hash,
                order.number
              ),
              "session_id={CHECKOUT_SESSION_ID}"
            ],
            "?"
          ),
        cancel_url: Routes.gallery_client_show_cart_url(socket, :cart, gallery.client_link_hash)
      })
      |> Payments.checkout_link(
        connect_account: gallery.job.client.organization.stripe_account_id
      )

    checkout_link
  end

  defp schedule_products_ordering(%{assigns: %{order: order}} = socket),
    do: assign(socket, :ordering_task, Task.async(fn -> Cart.create_whcc_order(order) end))

  defp only_digitals?(%{products: []} = order), do: digitals?(order)
  defp only_digitals?(%{products: [_ | _]}), do: false
  defp digitals?(%{digitals: [_ | _]}), do: true
  defp digitals?(%{digitals: [], bundle_price: %Money{}}), do: true
  defp digitals?(_), do: false
  defp show_cart?(:product_list), do: true
  defp show_cart?(_), do: false

  defp zero_subtotal?(order),
    do: only_digitals?(order) && order |> total_cost() |> Money.zero?()

  defp item_id(item), do: item.editor_id

  defdelegate cart_count(order), to: Cart, as: :item_count
  defdelegate item_image_url(item), to: Cart
  defdelegate lines_by_product(order), to: Cart
  defdelegate product_name(product), to: Cart
  defdelegate product_quantity(product), to: Cart
  defdelegate summary(assigns), to: __MODULE__.Summary
  defdelegate total_cost(order), to: Cart

  defp zero_total?(order),
    do: only_digitals?(order) && order |> total_cost() |> Money.zero?()
end
