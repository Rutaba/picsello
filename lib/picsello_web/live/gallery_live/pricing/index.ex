defmodule PicselloWeb.GalleryLive.Pricing.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_photographer"]

  import PicselloWeb.LiveHelpers
  import PicselloWeb.GalleryLive.Shared
<<<<<<< HEAD
  import PicselloWeb.Shared.StickyUpload, only: [sticky_upload: 1]
=======
>>>>>>> 5f7bfb3ee (gallery local pricing feature)

  alias Picsello.{Galleries, Repo, Orders}
  alias Ecto.Multi
  
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:total_progress, 0)
    |> assign(:photos_error_count, 0)
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    gallery =
      Galleries.get_gallery!(id)
      |> Repo.preload([:photographer, :package, :gallery_digital_pricing])
      |> Galleries.load_watermark_in_gallery()

    prepare_gallery(gallery)

    socket
    |> is_mobile(params)
    |> assign(:has_order?, Orders.placed_orders_count(gallery) > 0)
    |> assign(:gallery, gallery)
    |> noreply()
  end

  @impl true
  def handle_event("back_to_navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket |> assign(:is_mobile, !is_mobile) |> noreply
  end

  @impl true
  def handle_event("edit-global-pricing", _, socket) do
    socket
    |> redirect(to: "/galleries/settings?section=products")
    |> noreply
  end

  @impl true
  def handle_event("edit-digital-pricing", _, %{assigns: assigns} = socket) do
    socket
    |> open_modal(
      PicselloWeb.GalleryLive.Pricing.GalleryDigitalPricingComponent,
      assigns |> Map.take([:current_user, :gallery])
    )
    |> noreply()
  end

  @impl true
  def handle_event("confirm-reset-digital-pricing", _, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> PicselloWeb.GalleryLive.Pricing.ConfirmationComponent.open(%{
      title: "You're resetting this gallery's pricing",
      payload: %{gallery: gallery}
    })
    |> noreply()
  end

  @impl true
  defdelegate handle_event(event, params, socket), to: PicselloWeb.GalleryLive.Shared

  @impl true
  def handle_info({:message_composed, message_changeset}, socket) do
    add_message_and_notify(socket, message_changeset, "gallery")
  end

  @impl true
  def handle_info(
        {:save, %{title: title}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> close_modal()
    |> assign(products: Galleries.products(gallery))
    |> put_flash(:success, "#{title} successfully updated")
    |> noreply
  end

  @impl true
  def handle_info({:gallery_progress, %{total_progress: total_progress}}, socket) do
    socket
    |> assign(:total_progress, if(total_progress == 0, do: 1, else: total_progress))
    |> noreply()
  end

  @impl true
  def handle_info({:uploading, %{success_message: success_message}}, socket) do
    socket |> put_flash(:success, success_message) |> noreply()
  end

  @impl true
  def handle_info(
        {:photos_error, %{photos_error_count: photos_error_count, entries: entries}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    if length(entries) > 0, do: inprogress_upload_broadcast(gallery.id, entries)

    socket
    |> assign(:photos_error_count, photos_error_count)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "reset-digital-pricing", %{gallery: gallery}},
        socket
      ) do
    case Galleries.reset_gallery_pricing(gallery) do
      {:ok, updated_gallery} ->
        updated_gallery =
          updated_gallery
          |> Repo.preload([:photographer, :package])
          |> Galleries.load_watermark_in_gallery()

        socket
        |> assign(:gallery, updated_gallery)
        |> put_flash(:success, "Gallery pricing reset to package")

      _ ->
        socket
        |> put_flash(:error, "Gallery pricing could not reset to package")
    end
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info({:update, %{changeset: changeset, gallery_changeset: gallery_changeset}}, %{assigns: %{gallery: gallery}} = socket) do
    Multi.new()
    |> Multi.update(:gallery_digital_pricing, changeset)
    |> Multi.update(:gallery, gallery_changeset)
    |> Repo.transaction()
    |> case do
      {:ok, %{gallery_digital_pricing: _gallery_digital_pricing}} ->
        socket
        |> assign(:gallery, Repo.preload(gallery, :gallery_digital_pricing, force: true))
        |> put_flash(:success, "Gallery pricing updated")

      {:error, :gallery_digital_pricing, _changeset, _} ->
        socket
        |> put_flash(:error, "Couldn't update gallery pricing")

      other -> other
    end
    |> close_modal()
    |> noreply()
  end

  def grid_item(assigns) do
    ~H"""
      <div class="flex flex-row mt-2 items-center">
        <div class="flex">
            <div class="flex items-center justify-center flex-shrink-0 w-8 h-8 rounded-full bg-blue-planning-300">
              <.icon name={@icon} class="w-4 h-4 text-white fill-current"/>
            </div>
        </div>
        <div class="flex flex-col ml-2">
            <p class="text-blue-planning-300 font-bold"><%= @item_name %></p>
            <p class="text-base-250 font-normal"><%= @item_value %></p>
        </div>
      </div>
    """
  end

  def get_pricing_value(gallery) do
    if gallery.gallery_digital_pricing, do: gallery.gallery_digital_pricing, else: gallery.package
  end
end
