defmodule PicselloWeb.GalleryLive.ClientAlbum do
  @moduledoc false

  use PicselloWeb,
    live_view: [
      layout: "live_gallery_client"
    ]

  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Repo, Galleries, GalleryProducts, Albums, Cart, Orders}
  alias PicselloWeb.GalleryLive.Photos.Photo.ClientPhoto
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias Picsello.Galleries.Watermark

  @per_page 12

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:photo_updates, "false")
    |> assign(:download_all_visible, false)
    |> assign(:selected_filter, false)
    |> assign(:client_proofing, "true")
    |> ok()
  end

  @impl true
  def handle_params(%{"album_id" => album_id}, _, socket) do
    socket
    |> assign(:album, %{is_proofing: false, is_finals: false} = Albums.get_album!(album_id))
    |> assign(:is_proofing, false)
    |> assigns()
  end

  def handle_params(
        %{"editorId" => whcc_editor_id},
        _,
        %{
          assigns: %{
            album: album
          }
        } = socket
      ) do
    socket
    |> place_product_in_cart(whcc_editor_id)
    |> push_redirect(
      to: Routes.gallery_client_show_cart_path(socket, :proofing_album, album.client_link_hash)
    )
    |> noreply()
  end

  def handle_params(%{"hash" => _hash}, _, %{assigns: %{album: album}} = socket) do
    album = album |> Repo.preload(:gallery)

    socket
    |> assign(:album, album)
    |> assign(:is_proofing, !album.is_finals)
    |> assigns()
  end

  @impl true
  def handle_event(
        "load-more",
        _,
        %{
          assigns: %{
            page: page
          }
        } = socket
      ) do
    socket
    |> assign(:update_mode, "append")
    |> assign(page: page + 1)
    |> assign_photos(@per_page)
    |> noreply()
  end

  @impl true
  def handle_event("toggle_favorites", _, %{assigns: assigns} = socket) do
    %{gallery: gallery, album: album, favorites_filter: favorites_filter} = assigns

    Galleries.get_album_photo_count(gallery.id, album.id, !favorites_filter)
    |> then(&assign(socket, :photos_count, &1))
    |> toggle_favorites(@per_page)
  end

  def handle_event("toggle_selected", _, %{assigns: assigns} = socket) do
    %{gallery: gallery, album: album, selected_filter: selected_filter} = assigns

    gallery.id
    |> Galleries.get_album_photo_count(album.id, false, !selected_filter)
    |> then(&assign(socket, :photos_count, &1))
    |> assign(:page, 0)
    |> assign(:selected_filter, !selected_filter)
    |> assign(:update_mode, "replace")
    |> push_event("reload_grid", %{})
    |> assign_photos(@per_page)
    |> noreply()
  end

  @impl true
  def handle_event("product_preview_photo_popup", %{"params" => product_id}, socket) do
    socket |> product_preview_photo_popup(product_id)
  end

  @impl true
  def handle_event(
        "product_preview_photo_popup",
        %{"photo-id" => photo_id, "template-id" => template_id},
        socket
      ) do
    socket |> product_preview_photo_popup(photo_id, template_id)
  end

  @impl true
  def handle_event("click", %{"preview_photo_id" => photo_id}, socket) do
    socket |> client_photo_click(photo_id, %{close_event: :update_assigns_state})
  end

  def handle_info(
        {:customize_and_buy_product, whcc_product, photo, size},
        %{assigns: %{favorites_filter: favorites_filter}} = socket
      ) do
    socket
    |> customize_and_buy_product(whcc_product, photo,
      size: size,
      favorites_only: favorites_filter
    )
  end

  def handle_info(
        {:add_digital_to_cart, digital, finals_album_id},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    order = Cart.place_product(digital, gallery.id, finals_album_id)
    socket |> add_to_cart_assigns(order)
  end

  def handle_info(
        {:add_bundle_to_cart, bundle_price},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    order = Cart.place_product({:bundle, bundle_price}, gallery.id)
    socket |> add_to_cart_assigns(order)
  end

  def handle_info({:open_choose_product, photo_id}, socket) do
    socket |> client_photo_click(photo_id)
  end

  def handle_info(:update_cart_count, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:order, nil)
    |> assign_cart_count(gallery)
    |> noreply()
  end

  def handle_info({:update_assigns_state, _modal}, socket) do
    socket
    |> assigns()
    |> elem(1)
    |> assign(:update_mode, "replace")
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  defp assigns(%{assigns: %{album: album, gallery: gallery}} = socket) do
    album = album |> Repo.preload(:photos)
    gallery = gallery |> Repo.preload(:watermark)
    gallery = Galleries.populate_organization_user(gallery)

    if album.is_proofing && is_nil(gallery.watermark) do
      %{job: %{client: %{organization: %{name: name}}}} = Galleries.populate_organization(gallery)

      album.photos
      |> Enum.filter(&is_nil(&1.watermarked_url))
      |> Enum.each(&ProcessingManager.start(&1, Watermark.build(name, gallery)))
    end

    socket
    |> assign(
      favorites_count: Galleries.gallery_favorites_count(gallery),
      favorites_filter: false,
      gallery: gallery,
      album: album,
      photos_count: Galleries.get_album_photo_count(gallery.id, album.id),
      page: 0,
      page_title: "Show Album",
      download_all_visible: Orders.can_download_all?(gallery),
      products: GalleryProducts.get_gallery_products(gallery.id, :coming_soon_false),
      update_mode: "append",
      credits: Cart.credit_remaining(gallery) |> credits()
    )
    |> assign_cart_count(gallery)
    |> assign_photos(@per_page)
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  defp top_section(%{is_proofing: false} = assigns) do
    ~H"""
    <%= if @album.is_finals do %>
      <div class="text-lg font-bold lg:text-3xl">Your Photos</div>
      <div class="flex flex-col lg:flex-row justify-between lg:items-center my-4 w-full">
        <div class="flex items-center mt-4">
          <.button
          element="a"
          icon="download"
          icon_class="h-4 w-4 fill-current"
          class="py-1.5 px-8"
          download
          href={Routes.gallery_downloads_path(
              @socket, :download_all,
              @gallery.client_link_hash,
              photo_ids: @album.photos |> Enum.map(& &1.id) |> Enum.join(","),
              is_client: true
          )}>
          Download all photos
          </.button>

          <.photos_count photos_count={@photos_count} class="ml-4" />
        </div>
        <.toggle_filter title="Show favorites only" event="toggle_favorites" applied?={@favorites_filter} />
      </div>
    <% else %>
      <div class="flex flex-col sm:flex-row sm:justify-between sm:items-end">
        <div class="text-lg font-bold lg:text-3xl">Your Photos</div>
        <.toggle_filter title="Show favorites only" event="toggle_favorites" applied?={@favorites_filter} />
      </div>
      <.photos_count {assigns} class="mb-8 lg:mb-16" />
    <% end %>
    """
  end

  defp top_section(%{is_proofing: true} = assigns) do
    ~H"""
      <h3 {testid("album-title")} class="text-lg font-bold lg:text-3xl"><%= @album.name %></h3>
      <p class="mt-2 text-lg font-normal">Select your favourite photos below
        and then send those selections to your photographer for retouching.
      </p>
    <.photos_count {assigns} />
    """
  end

  defp toggle_empty_state(assigns) do
    ~H"""
      <div class="relative justify-between mb-12 text-2xl font-bold text-center text-base-250">
        <%= if !@is_proofing do %>
          Oops, you have no liked photos!
        <% else %>
          Oops, you have no selected photos!
        <% end %>
      </div>
    """
  end

  defp photos_count(%{is_proofing: true, album: album, socket: socket} = assigns) do
    cart_route =
      Routes.gallery_client_show_cart_path(socket, :proofing_album, album.client_link_hash)

    ~H"""
    <div class="flex flex-col justify-between w-full my-4 lg:flex-row lg:items-center">
      <div class="flex items-center">
        <%= live_redirect to: cart_route do %>
          <button class="py-8 btn-primary">Review my Selections</button>
        <% end %>
        <.photos_count photos_count={@photos_count} class="ml-4" />
      </div>
      <.toggle_filter title="Show selected only" event="toggle_selected" applied?={@selected_filter} />
    </div>
    """
  end

  defp photos_count(%{photos_count: count} = assigns) do
    count = (count && "#{count} #{ngettext("photo", "photos", count)}") || "photo"

    ~H[<div class={"text-sm lg:text-xl text-base-250 #{@class}"}> <%= count %></div>]
  end

  defp photos_count(nil), do: "photo"
  defp photos_count(count), do: "#{count} #{ngettext("photo", "photos", count)}"

  defp toggle_filter(%{applied?: applied?} = assigns) do
    class_1 = if applied?, do: ~s(bg-blue-planning-100), else: ~s(bg-gray-200)
    class_2 = if applied?, do: ~s(right-1), else: ~s(left-1)

    ~H"""
    <div class="flex mt-4 lg:mt-0">
      <label id="toggle_favorites" class="flex items-center cursor-pointer">
        <div class="text-sm lg:text-xl text-base-250"><%= @title %></div>

        <div class="relative ml-3">
          <input type="checkbox" class="sr-only" phx-click={@event}>

          <div class={"block h-8 border rounded-full w-14 border-blue-planning-300 #{class_1}"}></div>
          <div class={"absolute w-6 h-6 rounded-full dot top-1 bg-blue-planning-300 transition #{class_2}"}></div>
        </div>
      </label>
    </div>
    """
  end
end
