defmodule PicselloWeb.GalleryLive.Shared do
  @moduledoc "Shared function among gallery liveViews"

  use Phoenix.Component
  import PicselloWeb.LiveHelpers
  import Money.Sigils

  alias Picsello.{Repo, Cart, Galleries, GalleryProducts, Messages}
  alias PicselloWeb.GalleryLive.{Shared.ConfirmationComponent, Photos.Upload}
  alias Picsello.Notifiers.ClientNotifier
  alias PicselloWeb.Router.Helpers, as: Routes

  def toggle_favorites(
        %{
          assigns: %{
            favorites_filter: favorites_filter
          }
        } = socket,
        per_page
      ) do
    toggle_state = !favorites_filter

    socket
    |> assign(:page, 0)
    |> assign(:favorites_filter, toggle_state)
    |> assign(:update_mode, "replace")
    |> assign_photos(per_page)
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  def client_photo_click(
        %{
          assigns: %{
            gallery: gallery,
            favorites_filter: favorites_filter
          }
        } = socket,
        photo_id
      ) do
    photo_ids = Galleries.get_gallery_photo_ids(gallery.id, favorites_filter: favorites_filter)

    photo_id = to_integer(photo_id)

    socket
    |> open_modal(
      PicselloWeb.GalleryLive.ChooseProduct,
      %{
        gallery: gallery,
        photo_id: photo_id,
        photo_ids:
          photo_ids
          |> CLL.init()
          |> CLL.next(Enum.find_index(photo_ids, &(&1 == photo_id)) || 0)
      }
    )
    |> noreply
  end

  def product_preview_photo_popup(
        %{
          assigns: %{
            products: products
          }
        } = socket,
        product_id
      ) do
    gallery_product =
      Enum.find(products, fn product -> product.id == String.to_integer(product_id) end)

    socket
    |> open_modal(
      PicselloWeb.GalleryLive.EditProduct,
      %{
        category: gallery_product.category,
        photo: gallery_product.preview_photo
      }
    )
    |> noreply()
  end

  def product_preview_photo_popup(socket, photo_id, template_id) do
    photo = Galleries.get_photo(photo_id)

    template_id = template_id |> to_integer()

    category =
      GalleryProducts.get(id: template_id)
      |> then(& &1.category)

    socket
    |> open_modal(
      PicselloWeb.GalleryLive.EditProduct,
      %{
        category: category,
        photo: photo
      }
    )
    |> noreply()
  end

  def customize_and_buy_product(
        %{
          assigns: %{
            gallery: gallery,
            favorites_filter: favorites
          }
        } = socket,
        whcc_product,
        photo,
        size
      ) do
    created_editor =
      Picsello.WHCC.create_editor(
        whcc_product,
        photo,
        complete_url:
          Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash) <>
            "?editorId=%EDITOR_ID%",
        secondary_url:
          Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash) <>
            "?editorId=%EDITOR_ID%&clone=true",
        cancel_url: Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash),
        size: size,
        favorites_only: favorites
      )

    socket
    |> redirect(external: created_editor.url)
    |> noreply()
  end

  def expire_soon(gallery) do
    expired_at = get_expiry_date(gallery)

    case DateTime.compare(DateTime.utc_now() |> DateTime.truncate(:second), expired_at) do
      :lt -> false
      :gt -> true
    end
    |> never_expire(expired_at)
  end

  defp never_expire(result, expired_at) do
    result && DateTime.compare(get_expiry_date(), expired_at) != :eq
  end

  defp get_expiry_date(%{expired_at: expired_at}) do
    case expired_at do
      nil -> get_expiry_date()
      _ -> expired_at
    end
  end

  defp get_expiry_date() do
    {:ok, date} = DateTime.new(~D[3022-02-01], ~T[12:00:00], "Etc/UTC")
    date
  end

  def make_opts(
        %{
          assigns:
            %{
              page: page,
              favorites_filter: filter
            } = assigns
        },
        per_page,
        exclude_all \\ nil
      ) do
    if exclude_all do
      []
    else
      album = Map.get(assigns, :album, nil)

      if album do
        [album_id: album.id]
      else
        [exclude_album: true]
      end ++
        [favorites_filter: filter, limit: per_page + 1, offset: per_page * page]
    end
  end

  def assign_photos(
        %{
          assigns: %{
            gallery: %{id: id}
          }
        } = socket,
        per_page,
        exclude_all \\ nil
      ) do
    opts = make_opts(socket, per_page, exclude_all)
    photos = Galleries.get_gallery_photos(id, opts)

    socket
    |> assign(:photos, photos |> Enum.take(per_page))
    |> assign(:has_more_photos, photos |> length > per_page)
  end

  def make_popup(socket, opts) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: opts[:event],
      class: "dialog-photographer",
      confirm_class: Keyword.get(opts, :confirm_class, "btn-warning"),
      confirm_label: Keyword.get(opts, :confirm_label, "Yes, delete"),
      icon: Keyword.get(opts, :icon, "warning-orange"),
      title: opts[:title],
      subtitle: opts[:subtitle],
      payload: Keyword.get(opts, :payload, %{})
    })
    |> noreply()
  end

  def share_gallery(
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    case prepare_gallery(gallery) do
      {:ok, _} ->
        gallery = gallery |> Galleries.set_gallery_hash() |> Repo.preload(job: :client)

        %{body_template: body_html, subject_template: subject} =
          with [preset | _] <- Picsello.EmailPresets.for(gallery, :gallery_send_link) do
            Picsello.EmailPresets.resolve_variables(
              preset,
              {gallery},
              PicselloWeb.Helpers
            )
          end

        socket
        |> assign(:job, gallery.job)
        |> assign(:gallery, gallery)
        |> PicselloWeb.ClientMessageComponent.open(%{
          body_html: body_html,
          subject: subject,
          modal_title: "Share gallery",
          presets: [],
          enable_image: true,
          enable_size: true
        })
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Please add photos to the gallery before sharing")
        |> noreply()
    end
  end

  def prepare_gallery(%{id: gallery_id} = gallery) do
    photos = Galleries.get_gallery_photos(gallery_id, limit: 1)

    if length(photos) == 1 do
      [photo] = photos
      maybe_set_cover_photo(gallery, photo)
      maybe_set_product_previews(gallery, photo)
    end
  end

  def maybe_set_cover_photo(gallery, photo) do
    case gallery.cover_photo do
      nil ->
        gallery
        |> Galleries.save_gallery_cover_photo(%{
          cover_photo: %{
            id: photo.original_url,
            aspect_ratio: photo.aspect_ratio,
            width: photo.width,
            height: photo.height
          }
        })
        |> then(fn %{cover_photo: photo} -> {:ok, photo} end)

      _ ->
        {:ok, :already_set}
    end
  rescue
    _ -> :error
  end

  def maybe_set_product_previews(gallery, photo) do
    products = Galleries.products(gallery)

    previews =
      Enum.filter(products, fn product ->
        case product.preview_photo do
          %{id: nil} -> true
          nil -> true
          _ -> false
        end
      end)

    if length(previews) > 0 do
      Enum.each(previews, fn %{category_id: category_id} = product ->
        product
        |> Map.drop([:category, :preview_photo])
        |> GalleryProducts.upsert_gallery_product(%{
          preview_photo_id: photo.id,
          category_id: category_id
        })
      end)

      {:ok, photo}
    else
      {:ok, :already_set}
    end
  rescue
    _ -> :error
  end

  def add_message_and_notify(%{assigns: %{job: job}} = socket, message_changeset, shared_item)
      when shared_item in ~w(gallery album) do
    with {:ok, message} <- Messages.add_message_to_job(message_changeset, job),
         {:ok, _email} <- ClientNotifier.deliver_email(message, job.client.email) do
      socket
      |> close_modal()
      |> put_flash(:success, "#{String.capitalize(shared_item)} shared!")
      |> noreply()
    else
      _error ->
        socket
        |> put_flash(:error, "Something went wrong")
        |> close_modal()
        |> noreply()
    end
  end

  def assign_cart_count(
        %{assigns: %{order: %Picsello.Cart.Order{placed_at: %DateTime{}}}} = socket,
        _
      ),
      do: assign(socket, cart_count: 0)

  def assign_cart_count(
        %{assigns: %{order: %Picsello.Cart.Order{products: products, digitals: digitals} = order}} =
          socket,
        _
      )
      when is_list(products) and is_list(digitals) do
    socket
    |> assign(cart_count: Picsello.Cart.item_count(order))
  end

  def assign_cart_count(socket, gallery) do
    case Picsello.Cart.get_unconfirmed_order(gallery.id, preload: [:products, :digitals]) do
      {:ok, order} ->
        socket |> assign(order: order) |> assign_cart_count(gallery)

      _ ->
        socket |> assign(cart_count: 0, order: nil)
    end
  end

  def add_to_cart_assigns(%{assigns: %{gallery: gallery}} = socket, order) do
    socket
    |> assign(credits: credits(gallery))
    |> assign(order: order)
    |> assign_cart_count(gallery)
    |> close_modal()
    |> put_flash(:success, "Added!")
    |> noreply()
  end

  def inprogress_upload_broadcast(gallery_id, entries) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "inprogress_upload_update:#{gallery_id}",
      {:inprogress_upload_update, %{entries: entries}}
    )
  end

  def tracking(assigns) do
    assigns = assign_new(assigns, :class, fn -> "" end)

    ~H"""
    <div class={"flex items-center pt-3 md:px-8 #{@class}"}>
      <%= case tracking_info(@order, @item) do %>
        <% nil -> %>
          <.icon name="tracking-info" class="mr-2 w-7 h-7 md:mr-4"/>
          <p class="text-xs md:text-sm">We’ll provide tracking info once your item ships</p>

        <% %{shipping_info: info} -> %>
          <.icon name="order-shipped" class="mr-2 w-7 h-7 md:mr-4"/>

          <p class="text-xs md:text-sm"><span class="font-bold">Item shipped:</span>
            <%= for %{carrier: carrier, tracking_url: url, tracking_number: tracking_number} <- info do %>
              <a href={url} target="_blank" class="underline cursor-pointer">
                <%= carrier %>
                <%= tracking_number %>
              </a>
            <% end %>
          </p>
      <% end %>
    </div>
    """
  end

  defp tracking_info(%{whcc_order: %{orders: sub_orders}}, %{editor_id: editor_id}) do
    Enum.find_value(sub_orders, fn
      %{editor_id: ^editor_id, whcc_tracking: tracking} ->
        tracking

      _ ->
        nil
    end)
  end

  def actions(assigns) do
    assigns = assigns |> Enum.into(%{photo_selected: true})

    ~H"""
    <div id={@id} class={classes("relative",  %{"pointer-events-none opacity-40" => !@photo_selected})} phx-update={@update_mode} data-offset-y="10" phx-hook="Select">
      <div class={"flex items-center lg:p-0 p-3 dropdown " <> @class}>
        <div class="lg:mx-3">
          <span>Actions</span>
        </div>
        <.icon name="down" class="w-3 h-3 ml-auto mr-1 stroke-current stroke-2 open-icon" />
        <.icon name="up" class="hidden w-3 h-3 ml-auto mr-1 stroke-current stroke-2 close-icon" />
      </div>
      <ul class="absolute z-30 hidden w-full mt-2 bg-white border rounded-md popover-content border-base-200">
        <%= render_slot(@inner_block) %>
        <li class="flex items-center py-1 bg-base-200 rounded-b-md hover:opacity-75">
          <button phx-click={@delete_event} phx-value-id={@delete_value} class="flex items-center w-full h-6 py-2.5 pl-2 overflow-hidden font-sans text-gray-700 transition duration-300 ease-in-out text-ellipsis hover:opacity-75">
            <%= @delete_title %>
          </button>
          <.icon name="trash" class="flex w-4 h-5 mr-3 text-red-400 hover:opacity-75" />
        </li>
      </ul>
    </div>
    """
  end

  def button(assigns) do
    assigns = Map.put_new(assigns, :class, "")

    assigns =
      Enum.into(assigns, %{
        element: "button",
        class: "",
        icon: "forth",
        icon_class: "h-3 w-2 stroke-current stroke-[3px]"
      })

    button_attrs = Map.drop(assigns, [:inner_block, :__changed__, :class, :icon, :icon_class])

    ~H"""
    <.button_element {button_attrs} class={"#{@class}
        flex items-center justify-center p-2 font-medium text-base-300 bg-base-100 border border-base-300 min-w-[12rem]
        hover:text-base-100 hover:bg-base-300
        disabled:border-base-250 disabled:text-base-250 disabled:cursor-not-allowed disabled:opacity-60
    "}>
      <%= render_slot(@inner_block) %>

      <.icon name={@icon} class={"#{@icon_class} ml-2"} />
    </.button_element>
    """
  end

  def preview(assigns) do
    ~H"""
    <div class="fixed z-30 lg:h-[45%] bg-white scroll-shadow">
        <div class="absolute 2xl:top-5 top-2 2xl:right-6 right-4">
            <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2 sm:stroke-1"/>
            </button>
        </div>
        <div class="flex items-center mx-24 mt-2 font-sans text-2xl font-bold 2xl:mt-7 text-base-300 lg:justify-start">
            <p><%= @page_title %></p>
        </div>
        <h1 class="mx-24 mt-2 font-sans text-md 2xl:mt-5 text-base-300">
            <%= @title %>
        </h1>
        <div class="flex pt-3 pb-6 mx-24 2xl:pt-6 grid lg:grid-cols-3 grid-cols-1 lg:grid-rows-preview">
          <%= render_slot(@inner_block) %>
          <div class="description lg:ml-11 row-span-2 col-span-2">
              <p class="pt-3 pb-6 font-sans text-base 2xl:pt-6 lg:pb-11"><%= @description %></p>
              <button phx-click="save" phx-target={@myself} disabled={!@selected} class="w-full rounded-lg save-button btn-settings">Save</button>
          </div>
        </div>
    </div>
    <div id="gallery_form" class="pb-20 2xl:pt-60 lg:pt-40 pt-80 px-11 lg:mt-56 mt-72">
      <div
          phx-hook="MasonryGrid"
          phx-update="append"
          id="muuri-grid"
          class="grid muuri"
          data-page={@page}
          data-id="muuri-grid"
          data-uploading="0"
          data-total={@gallery.total_count}
          data-favorites-count={@favorites_count}
          data-is-favorites-shown={"#{@favorites_filter}"}
          data-is-sortable="false"
          data-has-more-photos={"#{@has_more_photos}"}
          data-photo-width="300">
          <%= for photo <- @photos do %>
          <%= live_component PicselloWeb.GalleryLive.Photos.Photo,
              id: photo.id,
              photo: photo,
              photo_width: 300,
              is_gallery_category_page: true,
              component: @myself
          %>
          <% end %>
      </div>
    </div>
    """
  end

  defp button_element(%{element: "a"} = assigns) do
    attrs = Map.drop(assigns, [:inner_block, :__changed__, :element])

    ~H"""
      <a {attrs}><%= render_slot(@inner_block) %></a>
    """
  end

  defp button_element(%{element: "button"} = assigns) do
    attrs = Map.drop(assigns, [:inner_block, :__changed__, :element])

    ~H"""
      <button {attrs}><%= render_slot(@inner_block) %></button>
    """
  end

  def product_option(assigns) do
    assigns = Enum.into(assigns, %{min_price: nil})

    ~H"""
    <div {testid("product_option_#{@testid}")} class="p-5 mb-4 border rounded xl:p-7 border-base-225 lg:mb-7">
      <div class="flex items-center justify-between">
        <div class="flex flex-col mr-2">
          <p class="text-lg font-semibold text-base-300"><%= @title %></p>

          <%= if @min_price do %>
            <p class="font-semibold text-base text-base-300 pt-1.5 text-opacity-60"> <%= @min_price %></p>
          <% end %>
        </div>

        <%= for button <- @button do %>
          <.button {button}><%= render_slot(button) %></.button>
        <% end %>
      </div>
    </div>
    """
  end

  def bundle_image(assigns) do
    ~H"""
    <div class="relative w-full h-full">
      <%= for c <- ~w[-rotate-3 rotate-2 rotate-0] do %>
        <div class="absolute top-0 bottom-0 left-0 right-0 flex justify-center">
          <img src={@url} class={"h-full object-contain object-center shadow #{c}"}>
        </div>
      <% end %>
    </div>
    """
  end

  def credits_footer(assigns) do
    ~H"""
    <%= unless @credits == [] do %>
    <div class="relative">
      <div class="absolute bottom-0 left-0 right-0 z-10 w-full h-24 sm:h-20 bg-base-100 shadow-top">
        <div class="container flex items-center justify-between h-full mx-auto px-7">
          <div class="flex flex-col items-start h-full py-4 justify-evenly sm:flex-row sm:items-center">
            <%= for {label, value} <- @credits do %>
              <dl class="flex items-center sm:mr-5" >
                <dt class="mr-2 font-extrabold">
                  <%= label %><span class="hidden sm:inline"> available</span>:
                </dt>

                <dd class="font-semibold"><%= value %></dd>
              </dl>
            <% end %>
          </div>

          <.icon name="gallery-info" class="fill-current text-base-300 w-7 h-7" />
        </div>
      </div>
    </div>
    <% end %>
    """
  end

  def credits(%Galleries.Gallery{} = gallery),
    do: gallery |> Picsello.Cart.credit_remaining() |> credits()

  def credits(credits) do
    for {label, key, zero} <- [
          {"Download Credits", :digital, 0},
          {"Print Credit", :print, ~M[0]USD}
        ],
        reduce: [] do
      acc ->
        case Map.get(credits, key) do
          ^zero -> acc
          value -> [{label, value} | acc]
        end
    end
  end

  def cards_width(frame_image), do: if(frame_image == "card.png", do: "198")

  def mobile_gallery_header(assigns) do
    ~H"""
      <div class="absolute top-0 left-0 z-20 w-screen h-20 px-10 py-6 lg:hidden shrink-0 bg-base-200">
        <p class="font-sans text-2xl font-bold"><%= @gallery_name %></p>
      </div>
    """
  end

  def sticky_upload(assigns) do
    ~H"""
      <div class="hidden">
        <%= live_render(@socket, Upload, id: "upload-button", session: %{"gallery_id" => @gallery_id, "album_id" => nil, "view" => "add_button"}, sticky: true) %>
        <%= live_render(@socket, Upload, id: "drag-drop", session: %{"gallery_id" => @gallery_id, "album_id" => nil, "view" => "drag_drop"}, sticky: true) %>
      </div>
    """
  end

  def add_album_button(assigns) do
    ~H"""
      <.icon_button {testid("add-album-popup")} class={"text-sm bg-white shadow-lg #{@class}"} title="Add Album" phx-click="add_album_popup" color="blue-planning-300" icon="plus">
        Add Album
      </.icon_button>
    """
  end

  def mobile_banner(assigns) do
    ~H"""
      <div class={"lg:hidden flex flex-row items-center #{@class}"}>
        <div class="flex items-center justify-center w-10 h-10 rounded-full bg-blue-planning-300" phx-click="back_to_navbar">
          <.icon name="back" class="items-center w-5 h-5 ml-auto mr-auto text-white stroke-current" />
        </div>
        <div class="flex flex-col ml-4">
          <div class="flex font-sans text-2xl font-bold"><%= @title %></div>
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    """
  end

  def order_details(assigns) do
    ~H"""
    <div class={@class}>
      <div class="mt-0 mb-4 ml-0 md:ml-5 md:mt-2">
        <h4 class="text-lg font-bold md:text-2xl">Order details</h4>
        <p class="pt-3 md:text-lg md:pt-5">Order number: <span class="font-medium"><%= @order.number %></span></p>
      </div>

      <hr class="hidden md:block mt-7 border-t-base-200" />

      <div class="divide-y divide-base-200">

        <%= for item <- @order.products do %>
          <div class="relative py-5 md:py-7 md:first:border-t md:border-base-200">
            <div class="grid grid-rows-1 grid-cols-cart md:grid-cols-cartWide">
              <img src={item_image_url(item)} class="h-24 mx-auto md:h-40"/>

              <div class="flex flex-col px-4 md:px-8 md:pt-4">
                <span class="text-sm md:text-base md:font-medium"> <%= product_name(item) %></span>

                <span class="pt-2 text-xs md:text-sm md:py-5">Quantity: <%= quantity(item) %></span>
              </div>

              <span class="text-base font-bold lg:text-2xl md:pr-8 md:self-center"><%= price_display(item) %></span>
            </div>

            <.tracking order={@order} item={item} class="md:absolute md:left-64 md:bottom-12" />
          </div>
        <% end %>

        <%= for digital <- @order.digitals do %>
          <div class="flex items-center justify-between py-7 md:py-10 md:px-11">
            <div class="flex items-center">
              <img class="w-[120px] h-[80px] md:w-[194px] md:h-[130px] object-contain mr-4 md:mr-14" src={item_image_url(digital)}/>

              <span>Digital download</span>
            </div>

            <div class="font-bold"><%= price_display(digital) %></div>
          </div>
        <% end %>

        <%= if @order.bundle_price do %>
          <div class="flex items-center justify-between py-7 md:py-10 md:px-11">
            <div class="flex items-center">
              <div class="w-[120px] h-[80px] md:w-[194px] md:h-[130px] mr-4 md:mr-14" >
              <.bundle_image url={item_image_url({:bundle, @gallery})} />
              </div>

              <span>All digital downloads</span>
            </div>

            <div class="font-bold"><%= @order.bundle_price %></div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defdelegate item_image_url(item), to: Cart
  defdelegate product_name(order), to: Cart
  defdelegate quantity(item), to: Cart.Product
  defdelegate price_display(product), to: Cart
end
