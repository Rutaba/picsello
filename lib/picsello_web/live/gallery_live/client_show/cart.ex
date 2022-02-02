defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.Cart
  alias Picsello.WHCC.Shipping
  alias Picsello.Galleries
  alias Picsello.GalleryProducts
  alias PicselloWeb.GalleryLive.ClientMenuComponent

  @impl true
  def mount(_params, _session, %{assigns: %{gallery: gallery}} = socket) do
    case Cart.get_unconfirmed_order(gallery.id) do
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
          to: Routes.gallery_client_show_path(socket, :show, gallery.client_link_hash)
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

  @impl true
  def handle_event(
        "delete_product",
        %{"editor-id" => editor_id},
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
    case Cart.delete_product(order, editor_id) do
      {:deleted, _} ->
        socket
        |> push_redirect(
          to: Routes.gallery_client_show_path(socket, :show, gallery.client_link_hash)
        )
        |> noreply()

      {:loaded, order} ->
        send_update(ClientMenuComponent, id: client_menu_id, cart_count: count - 1)

        socket
        |> assign(:order, order)
        |> noreply()
    end
  end

  @impl true
  def handle_event(
        "continue",
        _,
        %{
          assigns: %{
            step: :delivery_info,
            delivery_info_changeset: delivery_info_changeset,
            order: %{products: products} = order
          }
        } = socket
      ) do
    socket
    |> assign(:step, :shipping_opts)
    |> assign(:order, Cart.store_order_delivery_info(order, delivery_info_changeset))
    |> assign(:ordering_tasks, %{})
    |> assign_shipping_opts()
    |> schedule_products_ordering(products)
    |> noreply()
  end

  @impl true
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
  def handle_event(
        "checkout",
        _,
        %{
          assigns: %{
            step: :shipping_opts,
            order: order,
            gallery: gallery
          }
        } = socket
      ) do
    {:ok, %{link: checkout_link}} =
      payments().checkout_link(order,
        success_url:
          Routes.gallery_client_order_url(socket, :paid, gallery.client_link_hash, order.number),
        cancel_url: Routes.gallery_client_show_cart_url(socket, :cart, gallery.client_link_hash)
      )

    socket
    |> redirect(external: checkout_link)
    |> noreply()
  end

  def handle_event(
        "click",
        %{"option-uid" => option_uid, "product-editor-id" => editor_id},
        %{assigns: %{step: :shipping_opts, order: %{products: products}}} = socket
      ) do
    product = Enum.find(products, fn p -> p.editor_details.editor_id == editor_id end)

    socket
    |> update_shipping_opts(String.to_integer(option_uid), editor_id)
    |> schedule_products_ordering([product])
    |> noreply()
  end

  @impl true
  def handle_info({_ref, product}, %{assigns: %{ordering_tasks: tasks}} = socket) do
    Task.shutdown(tasks[product.editor_details.editor_id], :brutal_kill)

    socket
    |> assign(:order, Cart.store_cart_products_checkout([product]))
    |> assign(:ordering_tasks, Map.drop(tasks, [product.editor_details.editor_id]))
    |> noreply()
  end

  defp product_shipping_options(%{assigns: %{shipping_opts: shipping_opts}}, product) do
    shipping_opts
    |> Enum.find(fn opt ->
      opt[:editor_id] == product.editor_details.editor_id
    end)
    |> then(& &1.current)
  end

  defp schedule_products_ordering(socket, %{}) do
    socket
    |> noreply()
  end

  defp schedule_products_ordering(
         %{
           assigns: %{
             gallery: gallery,
             order: %{delivery_info: delivery_info},
             ordering_tasks: ordering_tasks
           }
         } = socket,
         products
       ) do
    account_id = Galleries.account_id(gallery)

    tasks =
      products
      |> Enum.reduce(ordering_tasks, fn product, tasks ->
        case ordering_tasks[product.editor_details.editor_id] do
          nil -> :ignore
          task -> Task.shutdown(task, :brutal_kill)
        end

        shipping_options = product_shipping_options(socket, product)

        Map.put(
          tasks,
          product.editor_details.editor_id,
          Task.async(fn ->
            try do
              order_product(product, account_id, delivery_info, shipping_options)
            rescue
              _ -> order_product(product, account_id, delivery_info, shipping_options)
            end
          end)
        )
      end)

    socket
    |> assign(:ordering_tasks, tasks)
  end

  defp order_product(product, account_id, delivery_info, shipping_options) do
    Cart.order_product(product, account_id,
      ship_to: form_ship_address(delivery_info),
      return_to: return_to_address(),
      attributes: Shipping.to_attributes(shipping_options)
    )
  end

  defp update_shipping_opts(%{assigns: %{shipping_opts: opts}} = socket, option_uid, editor_id) do
    socket
    |> assign(
      :shipping_opts,
      Enum.map(opts, fn
        %{editor_id: id, current: %{id: uid}} = opt
        when editor_id == id and option_uid == uid ->
          opt

        %{editor_id: id} = opt when editor_id == id ->
          Map.put(
            opt,
            :current,
            Enum.find(opt[:list], fn list_opt -> option_uid == list_opt.id end)
          )

        opt ->
          opt
      end)
    )
  end

  defp assign_shipping_opts(
         %{assigns: %{step: :shipping_opts, order: %{products: products}}} = socket
       ) do
    socket
    |> assign(
      :shipping_opts,
      Enum.map(products, fn product -> shipping_opts_for_product(product) end)
    )
  end

  defp display_shipping_opts(assigns) do
    ~H"""
    <form>
      <%= for option <- @options do %>
        <%= render_slot(@inner_block, option) %>
      <% end %>
    </form>
    """
  end

  defp shipping_opts_for_product(%{
         editor_details: %{
           editor_id: editor_id,
           selections: %{"size" => size},
           product_id: product_id
         },
         base_price: price
       }) do
    category = GalleryProducts.get_whcc_product_category(product_id)

    %{editor_id: editor_id, list: Shipping.options(category.whcc_name, size, price)}
    |> then(&Map.put(&1, :current, List.first(&1.list)))
  end

  defp shipping_opts_for_product(opts, %{editor_details: %{editor_id: editor_id}}) do
    Enum.find(opts, fn %{editor_id: id} -> id == editor_id end)
    |> then(& &1.list)
  end

  defp is_current_shipping_option?(opts, option, %{editor_details: %{editor_id: editor_id}}) do
    Enum.find(opts, fn %{editor_id: id} -> id == editor_id end)
    |> then(&(&1.current == option))
  end

  defp is_product_ordering?(ordering_tasks, product) do
    Map.has_key?(ordering_tasks, product.editor_details.editor_id)
  end

  defp shipping_option_uid(%{id: id}), do: id
  defp shipping_option_cost(%{price: price}), do: price
  defp shipping_option_label(%{name: label}), do: label

  defp return_to_address() do
    %{
      "Name" => "Returns Department",
      "Addr1" => "3432 Denmark Ave",
      "Addr2" => "Suite 390",
      "City" => "Eagan",
      "State" => "MN",
      "Zip" => "55123",
      "Country" => "US",
      "Phone" => "8002525234"
    }
  end

  defp form_ship_address(%{
         name: name,
         address: %{
           addr1: addr1,
           addr2: addr2,
           city: city,
           zip: zip,
           state: state,
           country: country
         }
       }) do
    %{
      "Name" => name,
      "Addr1" => addr1,
      "Addr2" => addr2,
      "City" => city,
      "State" => state,
      "Zip" => zip,
      "Country" => country
    }
  end

  defp payments, do: Application.get_env(:picsello, :payments)
end
