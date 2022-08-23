defmodule PicselloWeb.GalleryLive.ClientOrder do
  @moduledoc "Order display to client"

  use PicselloWeb, live_view: [layout: "live_gallery_client"]
  import PicselloWeb.GalleryLive.Shared

  alias PicselloWeb.GalleryLive.Shared.DownloadLinkComponent
  alias Picsello.{Orders, Galleries}

  @impl true
  def mount(_, _, %{assigns: %{live_action: live_action}} = socket) do
    socket
    |> assign(from_checkout: false)
    |> assign(is_proofing: live_action in [:proofing_album, :proofing_album_paid])
    |> ok()
  end

  @impl true
  def handle_params(
        %{"order_number" => order_number, "session_id" => session_id},
        _,
        %{assigns: %{gallery: gallery, live_action: live_action}} = socket
      )
      when live_action in ~w(paid proofing_album_paid)a do
    case Orders.handle_session(order_number, session_id) do
      {:ok, _order, :already_confirmed} ->
        Orders.get!(gallery, order_number)

      {:ok, _order, :confirmed} ->
        order = Orders.get!(gallery, order_number)

        Picsello.Notifiers.OrderNotifier.deliver_order_confirmation_emails(
          order,
          PicselloWeb.Helpers
        )

        order
    end
    |> then(fn order ->
      socket
      |> assign_details(order)
      |> process_checkout_order()
    end)
  end

  def handle_params(
        %{"order_number" => order_number},
        _,
        %{assigns: %{gallery: gallery, live_action: :proofing_album_paid}} = socket
      ) do
    order = Orders.get!(gallery, order_number)

    socket
    |> assign_details(order)
    |> then(&push_patch(&1, to: &1.assigns.checkout_routes.order, replace: true))
    |> noreply()
  end

  def handle_params(
        %{"order_number" => order_number, "session_id" => session_id},
        _,
        %{assigns: %{gallery: gallery, live_action: live_action}} = socket
      )
      when live_action in ~w(paid proofing_album_paid)a do
    case Orders.handle_session(order_number, session_id) do
      {:ok, _order, :already_confirmed} ->
        Orders.get!(gallery, order_number)

      {:ok, _order, :confirmed} ->
        order = Orders.get!(gallery, order_number)

        Picsello.Notifiers.OrderNotifier.deliver_order_confirmation_emails(
          order,
          PicselloWeb.Helpers
        )

        order
    end
    |> then(fn order ->
      socket
      |> assign_details(order)
      |> process_checkout_order()
    end)
  end

  def handle_params(
        %{"order_number" => order_number},
        _,
        %{assigns: %{gallery: gallery, live_action: :proofing_album_paid}} = socket
      ) do
    order = Orders.get!(gallery, order_number)

    socket
    |> assign_details(order)
    |> process_checkout_order()
  end

  def handle_params(
        %{"order_number" => order_number},
        _,
        %{assigns: %{gallery: gallery}} = socket
      ) do
    order = Orders.get!(gallery, order_number)
    Orders.subscribe(order)

    socket
    |> assign_details(order)
    |> noreply()
  end

  @impl true
  def handle_info({:pack, :ok, %{path: path}}, %{assigns: %{order: order}} = socket) do
    DownloadLinkComponent.update_path(order, path)

    socket |> noreply()
  end

  defp process_checkout_order(%{assigns: %{gallery: gallery}} = socket) do
    if connected?(socket) do
      socket
      |> push_patch(to: socket.assigns.checkout_routes.order, replace: true)
    else
      socket
    end
    |> assign(:photographer, Galleries.gallery_photographer(gallery))
    |> assign(from_checkout: true)
    |> noreply()
  end

  defp assign_details(socket, order) do
    gallery = order.gallery

    socket
    |> assign(
      gallery: gallery,
      order: order,
      organization_name: gallery.organization.name,
      shipping_address: order.delivery_info.address,
      shipping_name: order.delivery_info.name
    )
    |> assign_checkout_routes()
    |> assign_cart_count(gallery)
  end

  defp success_message(assigns) do
    ~H"""
    <div class="flex flex-col justify-between md:flex-row md:items-center">
      <h3 class="mt-8 text-lg font-extrabold md:text-3xl"><%= message_heading(@is_proofing) %></h3>

      <div class={"#{@is_proofing && 'hidden'} mt-8 text-lg"}>Order number: <span class="font-medium">
        <%= Orders.number(@order) %></span>
      </div>
    </div>
    <.message_description {assigns} />
    """
  end

  defp message_description(%{is_proofing: true} = assigns) do
    ~H"""
    <div>
      <p class="mt-8 text-lg">
        Your image selection was sent to your photographer! If you'd like to select additional images
        for retouching, you can always add more to your list.
      </p>
      <p class="mt-4 text-lg">
        Simple select more of your favourite images, and send your list to <%= @photographer.name %> again.
        They'll be notified that you've added new favourites to your list and get those ready for you
      </p>
    </div>
    """
  end

  defp message_description(%{is_proofing: false} = assigns) do
    ~H"""
    <div>
      <p class="mt-8 text-lg">
        Thank you for shopping with <%= @organization_name %>.
        We’ll send you a confirmation email with your order details.
        <%= if has_download?(@order) do %>
          You can download your purchased digital photos from the gallery at any time.
        <% end %>
      </p>
    </div>
    """
  end

  def message_heading(true), do: "Your Selections were Sent!"
  def message_heading(false), do: "Thank you for your order!"

  defp checkout_type(true), do: :proofing_album_order
  defp checkout_type(false), do: :order
  defdelegate has_download?(order), to: Picsello.Orders
  defdelegate summary(assigns), to: PicselloWeb.GalleryLive.ClientShow.Cart.Summary
  defdelegate canceled?(order), to: Picsello.Orders
end
