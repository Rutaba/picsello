defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.{Cart, Payments, WHCC, Galleries}
  alias PicselloWeb.GalleryLive.ClientMenuComponent
  alias WHCC.Shipping
  import PicselloWeb.GalleryLive.Shared
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, %{assigns: %{gallery: gallery}} = socket) do
    case Cart.get_unconfirmed_order(gallery.id, :preload_products) do
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

      %{assigns: %{order: %{products: products}}} = socket ->
        socket
        |> assign(:ordering_tasks, %{})
        |> schedule_products_ordering(products)
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
  def handle_info({_ref, product}, %{assigns: %{order: order, ordering_tasks: tasks}} = socket) do
    Task.shutdown(tasks[item_id(product)], :brutal_kill)
    tasks = Map.drop(tasks, [item_id(product)])

    socket
    |> assign(:order, Cart.store_cart_product_checkout(order, product))
    |> assign(:ordering_tasks, tasks)
    |> then(fn socket ->
      if Enum.empty?(tasks), do: socket |> redirect(external: checkout_link(socket)), else: socket
    end)
    |> noreply()
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
        case ordering_tasks[item_id(product)] do
          nil -> :ignore
          task -> Task.shutdown(task, :brutal_kill)
        end

        Map.put(
          tasks,
          item_id(product),
          Task.async(fn ->
            try do
              order_product(product, account_id, delivery_info)
            rescue
              _ -> order_product(product, account_id, delivery_info)
            end
          end)
        )
      end)

    socket
    |> assign(:ordering_tasks, tasks)
  end

  defp order_product(product, account_id, delivery_info) do
    Cart.order_product(product, account_id,
      ship_to: form_ship_address(delivery_info),
      return_to: return_to_address(),
      attributes: Shipping.to_attributes(product)
    )
  end

  defp summary(assigns) do
    assigns = assign_new(assigns, :class, fn -> "summary" end)

    ~H"""
    <div class={"flex flex-col border border-base-200 #{@class}"}>
      <button
        phx-click={JS.toggle(to: ".#{@class} > button .toggle") |> JS.toggle(to: ".#{@class} > .grid.toggle", display: "grid")}
        class="px-5 pt-4 mb-6 text-base-250">
        <div class="flex items-center pb-2">
          <.icon name="up" class="toggle w-5 h-2.5 stroke-2 stroke-current mr-2.5" />
          <.icon name="down" class="hidden toggle w-5 h-2.5 stroke-2 stroke-current mr-2.5" />
          See&nbsp;
          <span class="toggle">more</span>
          <span class="hidden toggle">less</span>
        </div>
        <hr class="mb-1 border-base-200">
      </button>

      <div class="px-5 grid grid-cols-[1fr,max-content] hidden toggle">
        <dl class="text-lg contents">
          <%= for {label, value} <- charges(@order) do %>
            <dt class="my-2"><%= label %></dt>

            <dd class="self-center justify-self-end"><%= value %></dd>
          <% end %>

          <dt class="my-2 text-2xl">Subtotal</dt>
          <dd class="self-center text-2xl justify-self-end"><%= Money.new(1000) %></dd>
        </dl>

        <hr class="my-3 col-span-2 border-base-200">

        <dl class="text-lg contents text-green-finances-300">
          <%= for {label, value} <- discounts(@order) do %>
            <dt class="my-2"><%= label %></dt>

            <dd class="self-center justify-self-end"><%= value %></dd>
          <% end %>
        </dl>

        <hr class="my-5 col-span-2 border-base-200">

        <dl class="contents">
          <dt class="my-2 text-2xl font-extrabold">Total</dt>

          <dd class="self-center text-2xl font-extrabold justify-self-end"><%= total_cost(@order) %></dd>
        </dl>
      </div>

      <button type="button" class="mx-5 mt-5 text-lg mb-7 btn-primary" phx-click="continue" disabled={zero_subtotal?(@order)}>Continue</button>

      <%= if zero_subtotal?(@order) do %>
        <em class="block pt-1 text-xs text-center">Minimum amount is $1</em>
      <% end %>
    </div>
    """
  end

  defp charges(order) do
    [
      {"Products (6)", Money.new(100)},
      {"Shipping & handling", "Included"},
      {"Digital Downloads (4)", Money.new(100)}
    ]
  end

  defp discounts(order) do
    [
      {"Volume discount", Money.new(100)},
      {"Digital download credit (4)", Money.new(100)},
      {"Print credit used", Money.new(100)}
    ]
  end

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

  defp only_digitals?(%{products: [], digitals: [_ | _]}), do: true
  defp only_digitals?(%{products: [], digitals: [], bundle_price: %Money{}}), do: true
  defp only_digitals?(_), do: false
  defp show_cart?(:product_list), do: true
  defp show_cart?(_), do: false

  defp zero_subtotal?(order),
    do: only_digitals?(order) && order |> total_cost() |> Money.zero?()

  defdelegate cart_count(order), to: Cart, as: :item_count
  defdelegate item_id(item), to: Cart.CartProduct, as: :id
  defdelegate item_image_url(item), to: Cart
  defdelegate priced_lines_by_product(order), to: Cart
  defdelegate product_id(item), to: Cart.CartProduct
  defdelegate product_name(product), to: Cart
  defdelegate product_quantity(product), to: Cart
  defdelegate total_cost(order), to: Cart
end
