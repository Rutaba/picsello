defmodule PicselloWeb.GalleryLive.Shared do
  @moduledoc "Shared function among gallery liveViews"

  use Phoenix.Component
  import PicselloWeb.LiveHelpers
  import PicselloWeb.Gettext, only: [ngettext: 3]

  alias Picsello.{Repo, Galleries, Messages}
  alias PicselloWeb.GalleryLive.Shared.{ConfirmationComponent, GalleryMessageComponent}
  alias Picsello.Notifiers.ClientNotifier
  alias PicselloWeb.Router.Helpers, as: Routes

  def make_opts(
        %{
          assigns:
            %{
              page: page,
              favorites_filter: filter
            } = assigns
        },
        per_page,
        exlclue_all \\ nil
      ) do
    if exlclue_all do
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

  def make_delete_popup(socket, opts) do
    payload = Keyword.get(opts, :payload, %{})

    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: opts[:event],
      class: "dialog-photographer",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: opts[:title],
      subtitle: opts[:subtitle],
      payload: payload
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
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    gallery = Repo.preload(gallery, job: :client)

    link = Routes.gallery_client_show_url(socket, :show, hash)
    client_name = gallery.job.client.name

    subject = "#{gallery.name} photos"

    html = """
    <p>Hi #{client_name},</p>
    <p>Your gallery is ready to view! You can view the gallery here: <a href="#{link}">#{link}</a></p>
    <p>Your photos are password-protected, so you’ll also need to use this password to get in: <b>#{gallery.password}</b></p>
    <p>Happy viewing!</p>
    """

    text = """
    Hi #{client_name},

    Your gallery is ready to view! You can view the gallery here: #{link}

    Your photos are password-protected, so you’ll also need to use this password to get in: #{gallery.password}

    Happy viewing!
    """

    socket
    |> assign(:job, gallery.job)
    |> assign(:gallery, gallery)
    |> GalleryMessageComponent.open(%{
      body_html: html,
      body_text: text,
      subject: subject,
      modal_title: "Share gallery"
    })
    |> noreply()
  end

  def add_message_and_notify(%{assigns: %{job: job}} = socket, message_changeset) do
    with {:ok, message} <- Messages.add_message_to_job(message_changeset, job),
         {:ok, _email} <- ClientNotifier.deliver_email(message, job.client.email) do
      socket
      |> close_modal()
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

  def assign_cart_count(%{assigns: %{order: %Picsello.Cart.Order{} = order}} = socket, _) do
    socket
    |> assign(cart_count: Picsello.Cart.item_count(order))
  end

  def assign_cart_count(socket, gallery) do
    case Picsello.Cart.get_unconfirmed_order(gallery.id) do
      {:ok, order} ->
        socket |> assign(order: order) |> assign_cart_count(gallery)

      _ ->
        socket |> assign(cart_count: 0, order: nil)
    end
  end

  def total(list) when is_list(list), do: list |> length
  def total(_), do: nil

  def actions(assigns) do
    ~H"""
    <div id={@id} class="relative" phx-update="ignore" data-offset-y="10" phx-hook="Select">
      <div class={"flex items-center dropdown " <> @class}>
          <div class="mx-3">
            <span>Actions</span>
          </div>
          <.icon name="down" class="w-3 h-3 ml-auto mr-1 stroke-current stroke-2 open-icon" />
          <.icon name="up" class="hidden w-3 h-3 ml-auto mr-1 stroke-current stroke-2 close-icon" />
      </div>
      <ul class="absolute z-30 hidden w-full mt-2 bg-white rounded-md popover-content">
        <%= render_slot(@inner_block) %>
        <li class="flex items-center bg-gray-200 rounded-b-md hover:bg-gray-300">
          <button phx-click={@delete_event} phx-value-id={@delete_value} class="flex items-center w-full h-6 py-4 pl-2 overflow-hidden font-sans text-gray-700 transition duration-300 ease-in-out text-ellipsis">
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
    button_attrs = Map.drop(assigns, [:inner_block, :__changed__, :class])

    ~H"""
    <button {button_attrs} class={"#{@class}
        flex items-center justify-center p-2 font-medium text-base-300 bg-base-100 border border-base-300 min-w-[12rem]
        hover:text-base-100 hover:bg-base-300
        disabled:border-base-250 disabled:text-base-250 disabled:cursor-not-allowed disabled:opacity-60
    "}>
      <%= render_slot(@inner_block) %>

      <.icon name="forth" class="ml-2 h-3 w-2 stroke-current stroke-[3px]" />
    </button>
    """
  end

  def preview(assigns) do
    ~H"""
    <div class="fixed z-30 bg-white scroll-shadow">
        <div class="absolute top-4 right-4">
            <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2 sm:stroke-1"/>
            </button>
        </div>
        <div class="flex items-center mx-24 mt-5 font-sans text-2xl font-bold text-base-300 lg:justify-start">
            <p><%= @page_title %></p>
        </div>
        <h1 class={classes("text-md mt-4 mx-24 font-sans", %{ "text-base-300" => !@selected, "text-orange-inbox-300" => @selected})}>
            <%= @title %>
        </h1>
        <div class="flex pt-6 pb-6 mx-24 grid grid-cols-3 grid-rows-preview">
          <%= render_slot(@inner_block) %>
          <div class="description ml-11 row-span-2 col-span-2">
              <p class="pt-3 font-sans text-base pb-11"><%= @description %></p>
              <button phx-click="save" phx-target={@myself} disabled={!@selected} class="w-full rounded-lg save-button btn-settings">Save</button>
          </div>
        </div>
    </div>
    <div id="gallery_form" class="pt-56 pb-11 px-11 mt-52">
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
              is_likable: false,
              is_removable: false,
              is_viewable: false,
              is_meatball: false,
              is_gallery_category_page: true,
              component: @myself
          %>
          <% end %>
      </div>
    </div>
    """
  end

  def summary_counts(order) do
    for {label, collection, format_fn} <- [
          {"Products", order.products, &sum_prices/1},
          {"Digitals", Enum.filter(order.digitals, &Money.positive?(&1.price)), &sum_prices/1},
          {"Digital credits used", Enum.filter(order.digitals, &Money.zero?(&1.price)),
           &credits_display/1}
        ] do
      {label, Enum.count(collection), format_fn.(collection)}
    end
  end

  defp credits_display(collection) do
    "#{ngettext("%{count} credit", "%{count} credits", Enum.count(collection))} - #{sum_prices(collection)}"
  end

  defp sum_prices(collection) do
    Enum.reduce(collection, Money.new(0), &Money.add(&2, &1.price))
  end

  defdelegate price_display(product), to: Picsello.Cart
end
