defmodule PicselloWeb.GalleryLive.Shared do
  @moduledoc "Shared function among gallery liveViews"

  use Phoenix.Component
  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  import PicselloWeb.EmailAutomationLive.Shared, only: [sort_emails: 2]

  alias Picsello.{
    Job,
    Repo,
    Galleries,
    GalleryProducts,
    Messages,
    Cart,
    Galleries.Album,
    Albums,
    Notifiers.ClientNotifier,
    GlobalSettings,
    Utils,
    EmailAutomations,
    EmailAutomation.EmailSchedule,
    EmailAutomationSchedules
  }

  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Cart.{Order, Digital}
  alias Galleries.{GalleryProduct, Photo}
  alias Picsello.Cart.Order
  alias Galleries.{GalleryProduct, Photo, GalleryClient}
  alias PicselloWeb.Router.Helpers, as: Routes

  @card_blank "/images/card_gray.png"

  def handle_event(
        "client-link",
        _,
        %{assigns: %{current_user: current_user, gallery: %{type: type} = gallery}} = socket
      ) do
    case prepare_gallery(gallery) do
      {:ok, _} ->
        gallery = gallery |> Galleries.set_gallery_hash() |> Repo.preload([:albums, job: :client])
        preset_state = preset_state(type)
        state = automation_state(type)
        pipeline = EmailAutomations.get_pipeline_by_state(state)
        email_by_state = get_gallery_email_by_pipeline(gallery.id, pipeline)

        last_completed_email =
          EmailAutomationSchedules.get_last_completed_email(
            :gallery,
            gallery.id,
            nil,
            pipeline.id,
            state,
            PicselloWeb.EmailAutomationLive.Shared
          )

        manual_toggle =
          if is_manual_toggle?(email_by_state) and is_nil(last_completed_email),
            do: true,
            else: false

        %{body_template: body_html, subject_template: subject} =
          get_email_body_subject(email_by_state, gallery, preset_state)

        socket
        |> assign(:job, gallery.job)
        |> assign(:gallery, gallery)
        |> PicselloWeb.ClientMessageComponent.open(%{
          body_html: body_html,
          subject: subject,
          modal_title: modal_title(type),
          presets: [],
          enable_image: true,
          enable_size: true,
          composed_event: composed_event(type),
          client: Job.client(gallery.job),
          current_user: current_user,
          manual_toggle: manual_toggle,
          email_schedule: email_by_state
        })
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Please add photos to the gallery before sharing")
        |> noreply()
    end
  end

  def handle_event("download-photo", %{"uri" => uri}, socket) do
    socket
    |> push_event("download", %{uri: uri})
    |> noreply
  end

  def handle_info({:validate, %{"gallery" => %{"name" => name}}}, socket),
    do:
      socket
      |> assign_gallery_changeset(%{name: name})
      |> assign(:edit_name, true)
      |> noreply

  def handle_info(:update_cart_count, %{assigns: %{gallery: gallery}} = socket),
    do:
      socket
      |> assign(:order, nil)
      |> assign_cart_count(gallery)
      |> noreply()

  def handle_info(
        {:save, %{"gallery" => %{"name" => name}}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    gallery =
      gallery
      |> Galleries.update_gallery(%{name: name})
      |> then(&Galleries.load_watermark_in_gallery(elem(&1, 1)))
      |> Repo.preload(:photographer, job: :client)

    socket
    |> assign(:gallery, gallery)
    |> assign(:edit_name, false)
    |> put_flash(:success, "Gallery updated successfully")
    |> noreply()
  end

  def assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket),
    do:
      socket
      |> assign(:changeset, Galleries.change_gallery(gallery) |> Map.put(:action, :validate))

  def assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket, attrs),
    do:
      socket
      |> assign(
        :changeset,
        Galleries.change_gallery(gallery, attrs) |> Map.put(:action, :validate)
      )
  defp get_email_body_subject(nil, gallery, preset_state) do
    with [preset | _] <- Picsello.EmailPresets.for(gallery, preset_state) do
      Picsello.EmailPresets.resolve_variables(
        preset,
        schemas(gallery),
        PicselloWeb.Helpers
      )
    end
  end

  defp get_email_body_subject(email_by_state, gallery, _preset_state) do
    EmailAutomations.resolve_variables(
      email_by_state,
      schemas(gallery),
      PicselloWeb.Helpers
    )
  end

  defp get_gallery_email_by_pipeline(_gallery_id, nil), do: nil

  defp get_gallery_email_by_pipeline(gallery_id, pipeline) do
    EmailAutomationSchedules.query_get_email_schedule(:gallery, gallery_id, nil, pipeline.id)
    |> Repo.all()
    |> Repo.preload(email_automation_pipeline: [:email_automation_category])
    |> sort_emails(pipeline.state)
    |> List.first()
  end

  defp is_manual_toggle?(nil), do: false
  defp is_manual_toggle?(%EmailSchedule{reminded_at: nil}), do: true
  defp is_manual_toggle?(_email), do: false

  defp schemas(%{type: :standard} = gallery), do: {gallery}
  defp schemas(%{albums: [album]} = gallery), do: {gallery, album}

  defp automation_state(:standard), do: :manual_gallery_send_link
  defp automation_state(:proofing), do: :manual_send_proofing_gallery
  defp automation_state(:finals), do: :manual_send_proofing_gallery_finals

  defp preset_state(:standard), do: :gallery_send_link
  defp preset_state(:proofing), do: :proofs_send_link
  defp preset_state(:finals), do: :album_send_link

  #
  defp modal_title(:standard), do: "Share gallery"
  defp modal_title(:proofing), do: "Share Proofing Album"
  defp modal_title(:finals), do: "Share Finals Album"

  defp composed_event(:standard), do: :message_composed
  defp composed_event(_type), do: :message_composed_for_album

  defp maybe_insert_gallery_client(gallery, email) do
    {:ok, gallery_client} = Galleries.insert_gallery_client(gallery, email)
    gallery_client
  end

  def get_client_by_email(%{client_email: client_email, gallery: gallery} = assigns) do
    result =
      with true <- is_nil(client_email),
           nil <- Map.get(assigns, :current_user) do
        %GalleryClient{email: gallery.job.client.email, gallery_id: gallery.id}
      else
        false -> maybe_insert_gallery_client(gallery, client_email)
        current_user -> maybe_insert_gallery_client(gallery, current_user.email)
      end

    if is_list(result) do
      result |> List.first()
    else
      result
    end
  end

  def toggle_favorites(
        %{
          assigns: %{
            favorites_filter: favorites_filter
          }
        } = socket,
        per_page
      ) do
    socket
    |> assign(:favorites_filter, !favorites_filter)
    |> process_favorites(per_page)
  end

  def toggle_photographer_favorites(
        %{
          assigns: %{
            photographer_favorites_filter: photographer_favorites_filter
          }
        } = socket,
        per_page
      ) do
    socket
    |> assign(:photographer_favorites_filter, !photographer_favorites_filter)
    |> process_favorites(per_page)
  end

  def process_favorites(socket, per_page) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign_photos(per_page)
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  def client_photo_click(
        %{
          assigns:
            %{
              gallery: gallery,
              favorites_filter: favorites_filter,
              gallery_client: gallery_client
            } = assigns
        } = socket,
        photo_id,
        config \\ %{}
      ) do
    album = Map.get(assigns, :album)

    photo_ids =
      Galleries.get_gallery_photo_ids(
        gallery.id,
        [favorites_filter: favorites_filter] ++ if(album, do: [album_id: album.id], else: [])
      )

    photo_id = to_integer(photo_id)

    socket
    |> open_modal(
      PicselloWeb.GalleryLive.ChooseProduct,
      Map.put(config, :assigns, %{
        is_proofing: assigns[:is_proofing] || false,
        album: assigns[:album],
        gallery: gallery,
        gallery_client: gallery_client,
        photo_id: photo_id,
        photo_ids:
          photo_ids
          |> CLL.init()
          |> CLL.next(Enum.find_index(photo_ids, &(&1 == photo_id)) || 0)
      })
    )
    |> noreply
  end

  def product_preview_photo_popup(
        %{assigns: %{gallery: gallery}} = socket,
        %GalleryProduct{} = product,
        %Photo{} = photo
      ) do
    is_finals = Map.get(socket.assigns, :album, %{}) |> Map.get(:is_finals, false)

    case GalleryProducts.editor_type(product) do
      :card when is_finals ->
        socket
        |> push_redirect(
          to:
            Routes.gallery_card_editor_path(
              socket,
              :finals_album,
              socket.assigns.album.client_link_hash
            )
        )

      :card ->
        socket
        |> push_redirect(
          to: Routes.gallery_card_editor_path(socket, :index, gallery.client_link_hash)
        )

      _ ->
        socket
        |> open_modal(PicselloWeb.GalleryLive.EditProduct, %{
          category: product.category,
          photo: photo
        })
    end
    |> noreply()
  end

  def product_preview_photo_popup(socket, photo_id, template_id) do
    socket
    |> product_preview_photo_popup(
      GalleryProducts.get(id: to_integer(template_id)),
      Galleries.get_photo(photo_id)
    )
  end

  def product_preview_photo_popup(
        %{
          assigns: %{
            products: products
          }
        } = socket,
        product_id
      ) do
    gallery_product = Enum.find(products, fn product -> product.id == to_integer(product_id) end)

    socket |> product_preview_photo_popup(gallery_product, gallery_product.preview_photo)
  end

  def customize_and_buy_product(socket, whcc_product, photo, opts \\ []) do
    Picsello.WHCC.create_editor(
      whcc_product,
      photo,
      Keyword.merge(
        editor_urls(socket),
        opts
      )
    )
    |> then(
      &(socket
        |> redirect(external: &1.url)
        |> noreply())
    )
  end

  defp editor_urls(
         %{assigns: %{gallery_client: gallery_client, album: %Album{is_finals: true} = album}} =
           socket
       ) do
    [
      complete_url:
        Routes.gallery_client_album_url(socket, :proofing_album, album.client_link_hash) <>
          "?editorId=%EDITOR_ID%",
      secondary_url:
        Routes.gallery_client_album_url(socket, :proofing_album, album.client_link_hash) <>
          "?editorId=%EDITOR_ID%&clone=true&clientEmail=#{gallery_client.email}",
      cancel_url: Routes.gallery_client_album_url(socket, :proofing_album, album.client_link_hash)
    ]
  end

  defp editor_urls(
         %{assigns: %{gallery_client: gallery_client, gallery: %Galleries.Gallery{} = gallery}} =
           socket
       ) do
    [
      complete_url:
        Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash) <>
          "?editorId=%EDITOR_ID%",
      secondary_url:
        Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash) <>
          "?editorId=%EDITOR_ID%&clone=true&clientEmail=#{gallery_client.email}",
      cancel_url: Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash)
    ]
  end

  def get_all_gallery_albums(gallery_id) do
    case client_liked_album(gallery_id) do
      nil -> Albums.get_albums_by_gallery_id(gallery_id)
      album -> Albums.get_albums_by_gallery_id(gallery_id) ++ [album]
    end
  end

  def expire_soon(gallery) do
    expired_at = get_expiry_date(gallery)

    case DateTime.compare(DateTime.utc_now() |> DateTime.truncate(:second), expired_at) do
      :lt -> false
      _ -> true
    end
    |> never_expire(expired_at)
  end

  def expired_at(organization_id) do
    case GlobalSettings.get(organization_id) do
      %{expiration_days: exp_days} when not is_nil(exp_days) and exp_days > 0 ->
        GSGallery.calculate_expiry_date(exp_days)

      _ ->
        nil
    end
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
    case exclude_all do
      nil ->
        assigns
        |> Map.get(:album)
        |> photos_album_opts()
        |> Enum.concat(
          photographer_favorites_filter: assigns[:photographer_favorites_filter] || false,
          favorites_filter: filter,
          selected_filter: assigns[:selected_filter] || false,
          limit: per_page + 1,
          offset: per_page * page
        )

      :only_valid ->
        [valid: true]

      _ ->
        []
    end
  end

  def photos_album_opts(%{id: "client_liked"}), do: []
  def photos_album_opts(%{id: id}), do: [album_id: id]
  def photos_album_opts(_), do: [exclude_album: true]

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

  def prepare_gallery(%{id: gallery_id} = gallery) do
    photos = Galleries.get_gallery_photos(gallery_id, opts())

    if length(photos) == 1 do
      [photo] = photos
      Galleries.may_be_prepare_gallery(gallery, photo)
    end
  end

  def add_message_and_notify(
        %{assigns: %{job: job, current_user: user}} = socket,
        message_changeset,
        recipients,
        shared_item
      )
      when shared_item in ~w(gallery album) do
    with {:ok, %{client_message: message, client_message_recipients: _}} <-
           Messages.add_message_to_job(message_changeset, job, recipients, user)
           |> Repo.transaction(),
         {:ok, _email} <- ClientNotifier.deliver_email(message, recipients) do
      socket
      |> put_flash(:success, "#{String.capitalize(shared_item)} shared!")
    else
      _error ->
        socket
        |> put_flash(:error, "Something went wrong")
    end
    |> close_modal()
    |> noreply()
  end

  def add_message_and_notify(
        %{assigns: %{current_user: user}} = socket,
        message_changeset,
        recipients
      ) do
    with {:ok, %{client_message: message, client_message_recipients: _}} <-
           Messages.add_message_to_client(message_changeset, recipients, user)
           |> Repo.transaction(),
         {:ok, _email} <- ClientNotifier.deliver_email(message, recipients) do
      socket
      |> put_flash(:success, "Email sent!")
    else
      _error ->
        socket
        |> put_flash(:error, "Something went wrong")
    end
    |> close_modal()
    |> noreply()
  end

  def assign_cart_count(
        %{assigns: %{order: %Order{placed_at: %DateTime{}}}} = socket,
        _
      ),
      do: assign(socket, cart_count: 0)

  def assign_cart_count(
        %{assigns: %{order: %Order{products: products, digitals: digitals} = order}} = socket,
        _
      )
      when is_list(products) and is_list(digitals) do
    socket
    |> assign(cart_count: Cart.item_count(order))
  end

  def assign_cart_count(socket, gallery) do
    case get_unconfirmed_order(socket, preload: [:products, :digitals]) do
      {:ok, order} ->
        digitals =
          order
          |> Map.get(:digitals, [])
          |> Map.new(&{&1.photo_id, &1})

        socket
        |> assign(order: order)
        |> assign_cart_count(gallery)
        |> assign(digitals: digitals)

      _ ->
        socket |> assign(cart_count: 0, order: nil, digitals: %{})
    end
  end

  def add_to_cart_assigns(%{assigns: %{gallery: gallery}} = socket, order) do
    socket
    |> assign(credits: credits(gallery))
    |> assign(order: order)
    |> assign_cart_count(gallery)
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

  def actions(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        photo_selected: true,
        selection_filter: false,
        client_liked_album: false,
        selected_photos: [],
        has_orders: true,
        favorite_album?: false
      })

    any_client_liked_photo? =
      Enum.any?(assigns[:selected_photos], &Galleries.get_photo_by_id(&1).client_liked)

    assigns = assigns |> Enum.into(%{any_client_liked_photo?: any_client_liked_photo?})

    ~H"""
    <div id={@id} class={classes("relative",  %{"pointer-events-none opacity-40" => !@photo_selected || @disabled})} phx-update={@update_mode} data-offset-y="10" phx-hook="Select">
      <div {testid("dropdown-#{@id}")} class={"flex items-center lg:p-0 p-3 dropdown " <> @class}>
        <div class="lg:mx-3">
          <span>Actions</span>
        </div>
        <.icon name="down" class="w-3 h-3 ml-auto mr-1 stroke-current stroke-2 open-icon" />
        <.icon name="up" class="hidden w-3 h-3 ml-auto mr-1 stroke-current stroke-2 close-icon" />
      </div>
      <ul class="absolute z-30 hidden w-full mt-2 bg-white border rounded-md popover-content border-base-200">
        <%= render_slot(@inner_block) %>
        <%= if @has_orders && !@favorite_album? do %>
        <li class={classes("flex items-center py-1 bg-base-200 rounded-b-md hover:opacity-75", %{"hidden" => @selection_filter || @client_liked_album || @any_client_liked_photo?})}>
          <button phx-click={@delete_event} phx-value-id={@delete_value} class="flex items-center w-full h-6 py-2.5 pl-2 overflow-hidden font-sans text-gray-700 transition duration-300 ease-in-out text-ellipsis hover:opacity-75">
            <%= @delete_title %>
          </button>
          <.icon name="trash" class="flex w-4 h-5 mr-3 text-red-400 hover:opacity-75" />
        </li>
        <% end %>
      </ul>
    </div>
    """
  end

  def button(assigns) do
    assigns =
      Enum.into(assigns, %{
        element: "button",
        class: "",
        icon: "forth",
        icon_class: "h-3 w-2 stroke-current stroke-[3px]"
      })

    button_attrs = Map.drop(assigns, [:inner_block, :__changed__, :class, :icon, :icon_class])
    assigns = Enum.into(assigns, %{button_attrs: button_attrs})

    ~H"""
    <.button_element {@button_attrs} class={"#{@class}
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
    <div class="fixed z-30 bg-white scroll-shadow">
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
          class="mb-6 grid muuri"
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

  def product_option(assigns) do
    assigns = Enum.into(assigns, %{min_price: nil, selected: nil})

    ~H"""
    <div {testid("product_option_#{@testid}")} class="p-5 mb-4 border rounded xl:p-7 border-base-225 lg:mb-7">
      <div class="flex items-center justify-between">
        <div class="flex flex-col mr-2">
          <p class="text-lg font-semibold text-base-300"><%= @title %></p>

          <%= if @min_price do %>
            <p class="font-semibold text-base text-base-300 pt-1.5 text-opacity-60"> <%= @min_price %></p>
          <% end %>
        </div>

        <div class="flex flex-col">
          <span class={"#{!@selected && 'hidden'} ml-16 text-xs font-medium italic"}>Selected</span>
          <%= for button <- @button do %>
            <.button {button}><%= render_slot(button) %></.button>
          <% end %>
        </div>
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
    assigns =
      Enum.into(
        assigns,
        %{
          expanded?: false,
          is_proofing: false,
          cart_count: 0,
          total_count: 0,
          for: nil,
          is_fixed: false
        }
      )

    ~H"""
      <div class={classes("relative", %{"hidden" => @for == :proofing_album_order || Enum.empty?(build_credits(@for, @credits, @total_count))})}>
          <div class={classes("bottom-0 left-0 right-0 z-10 w-full h-24 sm:h-20 bg-base-100 pointer-events-none", %{"fixed shadow-top" => @is_fixed and @for != :proofing_album, "absolute border-t border-base-225" => !@is_fixed or @for == :proofing_album })}>
          <div class="center-container gallery__container flex items-center justify-between h-full mx-auto px-7 sm:px-16">
            <div class="flex flex-col items-start h-full py-4 justify-evenly sm:flex-row sm:items-center">
              <%= for {label, value} <- build_credits(@for, @credits, @total_count) do %>
                <div>
                  <dl class="flex items-center sm:mr-5" >
                    <dt class="mr-2 font-extrabold">
                      <%= label %><span class="hidden sm:inline"> available</span>:
                    </dt>

                    <dd class="font-semibold"><%= value %></dd>
                  </dl>
                  <div {testid("selections")} class={!@for && "hidden"}>Selections <%= @cart_count %></div>
                </div>
              <% end %>
            </div>
            <.icon name="gallery-info" class="fill-current hidden text-base-300 w-7 h-7" />
          </div>
        </div>
      </div>
    """
  end

  def credits(%Galleries.Gallery{} = gallery),
    do: gallery |> Cart.credit_remaining() |> credits()

  def credits(credits) do
    for {label, key} <- [
          {"Download Credits", :digital},
          {"Print Credit", :print}
        ],
        reduce: [] do
      acc ->
        case Map.get(credits, key) do
          0 -> acc
          %{amount: 0} -> acc
          value -> [{label, value} | acc]
        end
    end
  end

  def cards_width(frame_image), do: if(frame_image == "card.png", do: "198")

  def mobile_gallery_header(assigns) do
    ~H"""
      <div class="absolute top-0 left-0 z-30 w-screen h-20 px-10 py-6 lg:hidden shrink-0 bg-base-200 z-[32]">
        <p class="font-sans text-2xl font-bold"><%= @gallery_name %></p>
      </div>
    """
  end

  def add_album_button(assigns) do
    ~H"""
      <.icon_button {testid("add-album-popup")} disabled={@disabled} class={"text-sm bg-white shadow-lg #{@class}"} title="Add Album" phx-click="add_album_popup" color="blue-planning-300" icon="plus">
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
    assigns = Enum.into(assigns, %{is_proofing: false})

    ~H"""
    <div class={@class}>
      <div class="mt-0 mb-4 ml-0 md:ml-5 md:mt-2">
      <h4 class="text-lg font-bold md:text-2xl"><%= if @is_proofing, do: "Your Selected Favorites", else: "Order details" %></h4>
        <%= unless @is_proofing do %>
          <p class="pt-3 md:text-lg md:pt-5">Order number: <span class="font-medium"><%= @order.number %></span></p>
        <% end %>
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
            <img class="w-[120px] h-[80px] md:w-[194px] md:h-[130px] object-contain mr-4 md:mr-14" src={item_image_url(digital, proofing_client_view?: @is_proofing)} />

              <span><%= product_name(digital, @is_proofing) %></span>
            </div>

            <div class="font-bold"><%= price_display(digital) %></div>
          </div>
        <% end %>

        <%= if @order.bundle_price && !@is_proofing do %>
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

  def product_name(item, is_proofing), do: name(item, is_proofing)

  def get_unconfirmed_order(
        %{assigns: %{gallery: gallery, album: album, gallery_client: gallery_client}},
        opts
      )
      when album.is_finals or album.is_proofing do
    opts =
      opts
      |> Keyword.put(:album_id, album.id)
      |> Keyword.put(:gallery_client_id, gallery_client.id)

    Cart.get_unconfirmed_order(gallery.id, opts)
  end

  def get_unconfirmed_order(%{assigns: %{gallery: gallery, gallery_client: gallery_client}}, opts) do
    opts =
      opts
      |> Keyword.put(:gallery_client_id, gallery_client.id)

    Cart.get_unconfirmed_order(gallery.id, opts)
  end

  # routes to use for proofing_album and gallery checkout flow
  def assign_checkout_routes(
        %{assigns: %{album: %{client_link_hash: hash} = album, order: order}} = socket
      )
      when album.is_finals or album.is_proofing do
    order_num = order && Order.number(order)

    assign(socket, :checkout_routes, %{
      orders: orders_path(socket, :proofing_album, hash),
      order: order && order_path(socket, :proofing_album, hash, order_num),
      order_paid: order && order_path(socket, :proofing_album_paid, hash, order_num),
      cart: cart_path(socket, :proofing_album, hash),
      cart_address: cart_path(socket, :proofing_album_address, hash),
      home_page: Routes.gallery_client_album_path(socket, :proofing_album, hash)
    })
  end

  def assign_checkout_routes(
        %{assigns: %{gallery: %{client_link_hash: hash}, order: order}} = socket
      ) do
    order_num = order && Order.number(order)

    assign(socket, :checkout_routes, %{
      orders: orders_path(socket, :show, hash),
      order: order && order_path(socket, :show, hash, order_num),
      order_paid: order && order_path(socket, :paid, hash, order_num),
      cart: cart_path(socket, :cart, hash),
      cart_address: cart_path(socket, :address, hash),
      home_page: Routes.gallery_client_index_path(socket, :index, hash)
    })
  end

  def assign_checkout_routes(%{assigns: %{gallery: _gallery}} = socket) do
    socket
    |> assign(:order, nil)
    |> assign_checkout_routes()
  end

  def assign_is_proofing(%{assigns: %{album: nil}} = socket) do
    assign(socket, is_proofing: false)
  end

  def assign_is_proofing(%{assigns: %{album: album}} = socket) do
    assign(socket, is_proofing: album.is_proofing)
  end

  def assign_is_proofing(socket), do: assign(socket, is_proofing: false)

  def steps(assigns) do
    assigns = Enum.into(assigns, %{target: nil, for: nil})

    ~H"""
    <a {if step_number(@step, @steps) > 1, do: %{href: "#", phx_click: "back", phx_target: @target, title: "back"}, else: %{}} class="flex">
      <%= unless @for == :sign_up do %>
        <span {testid("step-number")} class="px-2 py-0.5 mr-2 text-xs font-semibold rounded bg-blue-planning-100 text-blue-planning-300">
          Step <%= step_number(@step, @steps) %>
        </span>
      <% end %>

      <ul class="flex items-center inline-block">
        <%= for step <- @steps do %>
          <li class={classes(
            "block w-5 h-5 sm:w-3 sm:h-3 rounded-full ml-3 sm:ml-2",
            %{ "bg-blue-planning-300" => step == @step, "bg-gray-200" => step != @step }
            )}>
          </li>
        <% end %>
      </ul>
    </a>
    """
  end

  defdelegate item_image_url(item), to: Cart
  defdelegate item_image_url(item, opts), to: Cart
  defdelegate product_name(order), to: Cart
  defdelegate quantity(item), to: Cart.Product
  defdelegate price_display(product), to: Cart

  def client_liked_album(gallery_id) do
    photos = Galleries.get_gallery_photos(gallery_id, favorites_filter: true)

    if Enum.any?(photos) do
      %Album{
        id: "client_liked",
        photos: photos,
        name: "Client Favorites",
        is_client_liked: true,
        thumbnail_photo: nil,
        orders: []
      }
    end
  end

  def original_album_link(socket, %{id: id, gallery_id: gallery_id, album_id: album_id}) do
    case album_id do
      nil ->
        Routes.gallery_photos_index_path(
          socket,
          :index,
          gallery_id,
          go_to_original: true,
          photo_id: id
        )

      album_id ->
        Routes.gallery_photos_index_path(
          socket,
          :index,
          gallery_id,
          album_id,
          go_to_original: true,
          photo_id: id
        )
    end
  end

  def create_album(
        album,
        %{
          params: params,
          gallery_id: gallery_id,
          is_mobile: is_mobile,
          is_redirect: is_redirect
        },
        socket
      ) do
    if album do
      {album, message} =
        album
        |> Albums.update_album(params)
        |> upsert_album("Album settings successfully updated")

      send(self(), {:album_settings, %{message: message, album: album}})
      socket |> noreply()
    else
      is_mobile = if(is_mobile, do: [], else: [is_mobile: false])

      {album, message} =
        socket.assigns
        |> insert_album(params)
        |> upsert_album("Album successfully created")

      redirect_path =
        if is_redirect,
          do: Routes.gallery_photos_index_path(socket, :index, gallery_id, album.id, is_mobile),
          else: "/galleries/#{gallery_id}/albums/client_liked"

      socket
      |> push_redirect(to: redirect_path)
      |> put_flash(:success, message)
      |> noreply()
    end
  end

  def cover_photo_url(%{cover_photo: nil}), do: @card_blank

  def cover_photo_url(%{cover_photo: %{id: photo_id}}),
    do: Picsello.Galleries.Workers.PhotoStorage.path_to_url(photo_id)

  def place_product_in_cart(
        %{
          assigns:
            %{
              gallery: gallery,
              gallery_client: gallery_client
            } = assigns
        } = socket,
        whcc_editor_id
      ) do
    album = Map.get(assigns, :album)
    album_id = if album, do: Map.get(album, :id), else: nil

    cart_product = Cart.new_product(whcc_editor_id, gallery.id)
    Cart.place_product(cart_product, gallery, gallery_client, album_id)

    socket
  end

  def truncate_name(%{client_name: client_name}, max_length) do
    name_length = String.length(client_name)

    if name_length > max_length do
      String.slice(client_name, 0..max_length) <>
        "..." <>
        String.slice(client_name, (name_length - 10)..name_length)
    else
      client_name
    end
  end

  def toggle_preview(assigns) do
    assigns = Enum.into(assigns, %{disabled: nil, product_id: nil})

    ~H"""
    <label class="inline-flex relative items-center cursor-pointer">
      <div class="relative">
        <input type="checkbox" disabled={@disabled} class="sr-only peer disabled:opacity-75 disabled:cursor-default" phx-click={@click} phx-value-product_id={@product_id} checked={@checked} phx-target={@myself} >
        <div class="w-11 h-6 bg-gray-300 rounded-full peer peer-focus:ring-toggle-100 dark:peer-focus:ring-toggle-300 dark:bg-gray-800 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-toggle-100"></div>
      </div>
      <span class="ml-3 text-sm font-medium text-gray-900 dark:text-gray-300"><%= @text %></span>
    </label>
    """
  end

  def new_gallery_path(socket, %{type: :standard} = gallery) do
    Routes.gallery_photos_index_path(socket, :index, gallery.id)
  end

  def new_gallery_path(socket, %{albums: [%{id: album_id}]} = gallery) do
    Routes.gallery_photos_index_path(socket, :index, gallery.id, album_id, is_mobile: false)
  end

  def assign_count(socket, true, gallery),
    do: assign(socket, photos_count: Galleries.gallery_favorites_count(gallery))

  def assign_count(socket, false, _gallery), do: socket

  def standard?(%{type: type}), do: type == :standard
  def disabled?(%{status: status}), do: status == :disabled

  def order_status(%{intent: %{status: status}}) when is_binary(status),
    do: String.capitalize(status)

  def order_status(_), do: "Processed"

  def tag_for_gallery_type(assigns) do
    ~H"""
      <span class="lg:ml-[54px] sm:ml-0 inline-block mt-2 border rounded-md bg-base-200 px-2 pb-0.5 text-base-250 font-bold text-base"><%= Utils.capitalize_all_words(@type) %></span>
    """
  end

  def clip_board(socket, gallery) do
    albums = Albums.get_albums_by_gallery_id(gallery.id)

    proofing_album =
      albums
      |> Enum.filter(& &1.is_proofing)
      |> List.first()

    final_album =
      albums
      |> Enum.filter(& &1.is_finals)
      |> List.first()

    cond do
      final_album ->
        proofing_and_final_album_url(socket, final_album)

      proofing_album ->
        proofing_and_final_album_url(socket, proofing_album)

      true ->
        hash =
          gallery
          |> Galleries.set_gallery_hash()
          |> Map.get(:client_link_hash)

        Routes.gallery_client_index_url(socket, :index, hash)
    end
  end

  def is_photographer_view(assigns) do
    (Map.get(assigns, :current_user) && true) || false
  end

  defp opts(), do: [limit: 1, valid: true]

  defp schemas(%{type: :standard} = gallery), do: {gallery}
  defp schemas(%{albums: [album]} = gallery), do: {gallery, album}

  defp preset_state(:standard), do: :gallery_send_link
  defp preset_state(:proofing), do: :proofs_send_link
  defp preset_state(:finals), do: :album_send_link

  defp modal_title(:standard), do: "Share gallery"
  defp modal_title(:proofing), do: "Share Proofing Album"
  defp modal_title(:finals), do: "Share Finals Album"

  defp composed_event(:standard), do: :message_composed
  defp composed_event(_type), do: :message_composed_for_album

  defp step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  defp orders_path(socket, method, client_link_hash) do
    Routes.gallery_client_orders_path(socket, method, client_link_hash)
  end

  defp order_path(socket, method, client_link_hash, order_number) do
    Routes.gallery_client_order_path(socket, method, client_link_hash, order_number)
  end

  defp cart_path(socket, method, client_link_hash) do
    Routes.gallery_client_show_cart_path(socket, method, client_link_hash)
  end

  defp build_credits(nil, credits, _cart_count), do: credits

  defp build_credits(_, credits, total_count) do
    {_, remaining} = Enum.find(credits, &(elem(&1, 0) == "Download Credits")) || {"", 0}
    [{"Digital Image Credits", "#{remaining} out of #{total_count}"}]
  end

  defp name(%Digital{photo: photo}, true), do: "Selected for retouching - #{photo.name}"
  defp name(%Digital{}, false), do: "Digital download"
  defp name({:bundle, _}, false), do: "All digital downloads"
  defp name(item, false), do: Cart.product_name(item)

  defp upsert_album(result, message) do
    case result do
      {:ok, %Album{} = album} -> {album, message}
      {:ok, result} -> {result.album, message}
      _ -> {nil, "something went wrong"}
    end
  end

  defp insert_album(%{selected_photos: []}, album_params), do: Albums.insert_album(album_params)

  defp insert_album(%{selected_photos: selected_photos}, album_params) do
    case Albums.insert_album_with_selected_photos(album_params, selected_photos) do
      {:ok, album} -> {:ok, album.album}
      _ -> {nil, "something went wrong"}
    end
  end

  defp proofing_and_final_album_url(socket, album) do
    album = Albums.set_album_hash(album)
    Routes.gallery_client_album_url(socket, :proofing_album, album.client_link_hash)
  end

  defp tracking_info(%{whcc_order: %{orders: sub_orders}}, %{editor_id: editor_id}) do
    Enum.find_value(sub_orders, fn
      %{editor_ids: editor_ids, whcc_tracking: tracking} ->
        if editor_id in editor_ids, do: tracking

      _ ->
        nil
    end)
  end

  defp button_element(%{element: "a"} = assigns) do
    attrs = Map.drop(assigns, [:inner_block, :__changed__, :element])
    assigns = Enum.into(assigns, %{attrs: attrs})

    ~H"""
      <a {@attrs}><%= render_slot(@inner_block) %></a>
    """
  end

  defp button_element(%{element: "button"} = assigns) do
    attrs = Map.drop(assigns, [:inner_block, :__changed__, :element])
    assigns = Enum.into(assigns, %{attrs: attrs})

    ~H"""
      <button {@attrs}><%= render_slot(@inner_block) %></button>
    """
  end

  defp maybe_insert_gallery_client(gallery, email) do
    {:ok, gallery_client} = Galleries.insert_gallery_client(gallery, email)
    gallery_client
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
end
