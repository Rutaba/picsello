defmodule PicselloWeb.GalleryLive.ChooseProduct do
  @moduledoc "no doc"
  use PicselloWeb, :live_component
  alias Picsello.{Cart, Cart.Digital, Galleries, GalleryProducts, Cart.Digital, Photos}
  alias PicselloWeb.GalleryLive.Photos.PhotoView

  import PicselloWeb.GalleryLive.Shared,
    only: [
      credits_footer: 1,
      credits: 1,
      assign_cart_count: 2,
      get_unconfirmed_order: 2,
      assign_checkout_routes: 1,
      disabled?: 1
    ]

  import PicselloWeb.GalleryLive.Photos.Photo.Shared, only: [js_like_click: 2]

  @defaults %{
    cart_count: 0,
    cart_route: nil,
    cart: true,
    is_proofing: false
  }

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id} = assigns, socket) do
    gallery = Picsello.Repo.preload(gallery, :gallery_digital_pricing)
    socket
    |> assign(Map.merge(@defaults, assigns))
    |> assign(assigns)
    |> assign_details(photo_id)
    |> assign(:download_each_price, gallery.gallery_digital_pricing.download_each_price)
    |> then(fn
      %{assigns: %{is_proofing: true}} = socket ->
        socket

      socket ->
        socket
        |> assign(:products, GalleryProducts.get_gallery_products(gallery, :coming_soon_false))
    end)
    |> then(fn %{assigns: %{gallery: gallery}} = socket ->
      socket
      |> assign(:organization, gallery.job.client.organization)
    end)
    |> assign_checkout_routes()
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

  def handle_event("digital_add_to_cart", %{}, socket) do
    socket
    |> add_to_cart()
    |> noreply()
  end

  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    {:ok, _} = Photos.toggle_liked(id)

    socket |> noreply()
  end

  def handle_event(
        "remove_digital_from_cart",
        %{},
        %{assigns: %{photo: photo}} = socket
      ) do
    socket
    |> get_unconfirmed_order(preload: [:products, :digitals])
    |> then(fn {:ok, order} ->
      digital = Enum.find(order.digitals, &(&1.photo_id == photo.id))
      Cart.delete_product(order, digital_id: digital.id)
    end)

    send(self(), :update_cart_count)

    socket
    |> assign_details(photo.id)
    |> noreply()
  end

  def handle_event("photo_view", %{"photo_id" => photo_id}, %{assigns: assigns} = socket) do
    assigns = %{photo_id: photo_id, photo_ids: assigns.photo_ids, from: :choose_product, is_proofing: assigns.is_proofing}

    socket
    |> open_modal(PhotoView, %{assigns: assigns})
    |> noreply
  end

  def go_to_cart_wrapper(assigns) do
    ~H"""
    <%= if @count > 0 do %>
      <%= live_redirect to: @route, title: "cart", class: "block" do %><%= render_slot @inner_block %><% end %>
    <% else %>
      <div title="cart" ><%= render_slot @inner_block %></div>
    <% end %>
    """
  end

  defp add_to_cart(%{assigns: %{is_proofing: true} = assigns} = socket) do
    %{gallery: gallery, photo: photo, download_each_price: price} = assigns
    send(self(), :update_cart_count)

    date_time = DateTime.truncate(DateTime.utc_now(), :second)

    Cart.place_product(
      %Digital{
        photo: photo,
        price: price,
        inserted_at: date_time,
        updated_at: date_time
      },
      gallery,
      photo.album_id
    )

    assign_details(socket, photo.id)
  end

  defp add_to_cart(
         %{assigns: %{photo: photo, download_each_price: price, album: album}, root_pid: root_pid} =
           socket
       ) do
    finals_album_id = get_finals_album_id(album)
    send(root_pid, {:add_digital_to_cart, %Digital{photo: photo, price: price}, finals_album_id})
    socket
  end

  defp move_carousel(%{assigns: %{photo_ids: photo_ids}} = socket, fun) do
    photo_ids = fun.(photo_ids)

    socket
    |> assign(photo_ids: photo_ids)
    |> assign_details(photo_ids |> CLL.value())
  end

  defp assign_details(%{assigns: %{gallery: gallery, album: album}} = socket, photo_id) do
    %{digital: digital_credit} = credits = Cart.credit_remaining(gallery)
    photo = Galleries.get_photo(photo_id)
    proofing_album_id = get_proofing_album_id(album, photo)

    socket
    |> assign(
      digital_status: Cart.digital_status(gallery, photo, proofing_album_id),
      digital_credit: digital_credit,
      photo: photo,
      credits: credits(credits)
    )
    |> assign(:order, nil)
    |> assign_cart_count(gallery)
  end

  defp get_finals_album_id(%{is_finals: true, id: album_id}), do: album_id
  defp get_finals_album_id(_album), do: nil

  defp button_option(%{is_proofing: false} = assigns) do
    opts = [testid: "digital_download", title: "Digital Download"]
    assigns = assign(assigns, :opts, opts)
    ~H"""
      <%= case @digital_status do %>
      <% :in_cart -> %>
        <.option {@opts}>
          <:button disabled>In cart</:button>
        </.option>
      <% :purchased -> %>
        <.option {@opts}>
          <:button
            element="a"
            download
            icon="download"
            icon_class="h-4 w-4 fill-current"
            class="my-4 mr-4 py-1.5 px-8"
            href={Routes.gallery_downloads_path(@socket, :download_photo, @gallery.client_link_hash, @photo.id)}>
            Download
          </:button>
        </.option>
      <% _ -> %>
        <.option {@opts} min_price={if @digital_credit <= 0, do: @download_each_price}>
          <:button phx-target={@myself} phx-click="digital_add_to_cart">
            Add to cart
          </:button>
        </.option>
      <% end %>
    """
  end

  defp button_option(%{is_proofing: true} = assigns) do
    button_label =
      if assigns.order &&
           Enum.any?(assigns.order.digitals, fn digital -> digital.is_credit == false end) do
        "Remove from cart"
      else
        "Unselect"
      end
    digital_status = if Galleries.do_not_charge_for_download?(assigns.gallery), do: :available, else: assigns.digital_status
    opts = [testid: "digital_download", title: "Select for retouching"]

    assigns = assign(assigns, opts: opts, button_label: button_label, digital_status: digital_status)

    ~H"""
      <%= case @digital_status do %>
      <% :available -> %>
        <.option {@opts} min_price={if @digital_credit <= 0, do: @download_each_price}>
          <:button {testid("select")} phx-target={@myself} phx-click="digital_add_to_cart">
            <%= if @digital_credit > 0, do: "Select", else: "Add to cart" %>
          </:button>
        </.option>
      <% :in_cart -> %>
        <.option {@opts}>
          <:button phx-target={@myself} phx-click="remove_digital_from_cart" phx-value-photo-id={@photo.id}>
            <%= @button_label %>
          </:button>
        </.option>
        <% _ -> %>
        <.option {@opts} selected={true}>
          <:button disabled>Unselect</:button>
        </.option>
      <% end %>
    """
  end

  defp get_proofing_album_id(%{is_proofing: true}, photo), do: photo.album_id
  defp get_proofing_album_id(_album, _photo), do: nil

  defdelegate option(assigns), to: PicselloWeb.GalleryLive.Shared, as: :product_option
  defdelegate min_price(category, org_id, opts), to: Picsello.Galleries
end
