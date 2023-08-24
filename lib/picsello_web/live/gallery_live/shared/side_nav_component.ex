defmodule PicselloWeb.GalleryLive.Shared.SideNavComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared
  import Picsello.Utils, only: [products_currency: 0]
  import PicselloWeb.Shared.EditNameComponent, only: [edit_name_input: 1]

  alias Phoenix.PubSub

  @impl true
  def update(
        %{
          id: id,
          total_progress: total_progress,
          photos_error_count: photos_error_count,
          gallery: gallery,
          arrow_show: arrow_show,
          album_dropdown_show: album_dropdown_show,
          is_mobile: is_mobile
        } = params,
        socket
      ) do
    albums = get_all_gallery_albums(gallery.id)

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "photos_error:#{gallery.id}")
      PubSub.subscribe(Picsello.PubSub, "gallery_progress:#{gallery.id}")
    end

    currency = Picsello.Currency.for_gallery(gallery)
    album = Map.get(params, :selected_album, nil)

    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "upload_update:#{gallery.id}",
      {:upload_update, %{album_id: album && album.id}}
    )

    socket
    |> assign(:id, id)
    |> assign(:total_progress, total_progress)
    |> assign(:photos_error_count, photos_error_count)
    |> assign(:gallery, gallery)
    |> assign(:currency, currency)
    |> assign(:edit_name, false)
    |> assign(:is_mobile, is_mobile)
    |> assign(:albums, albums)
    |> assign(:arrow_show, arrow_show)
    |> assign(:album_dropdown_show, album_dropdown_show)
    |> assign(:selected_album, album)
    |> assign_gallery_changeset()
    |> ok()
  end

  @impl true
  def handle_event(
        "select_albums_dropdown",
        _,
        %{
          assigns: %{
            album_dropdown_show: album_dropdown_show
          }
        } = socket
      ) do
    socket
    |> assign(:album_dropdown_show, !album_dropdown_show)
    |> noreply()
  end

  defp bar(assigns) do
    ~H"""
    <div class={@class}>
      <%= live_redirect to: @route do %>
        <div class="flex items-center py-3 pl-3 pr-4 overflow-hidden text-sm rounded lg:h-11 lg:pl-2 lg:py-4 transition duration-300 ease-in-out text-ellipsis whitespace-nowrap hover:text-blue-planning-300">
          <div class="flex items-center justify-center flex-shrink-0 w-8 h-8 rounded-full bg-blue-planning-300">
              <img src={Routes.static_path(PicselloWeb.Endpoint, "/images/#{@icon}")} width="16" height="16"/>
          </div>
          <div class="ml-3">
            <span class={@arrow_show && "text-blue-planning-300"}><%= @title %></span>
          </div>
          <div class="flex items-center px-2 ml-auto">
            <%= render_slot(@inner_block) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp li(assigns) do
    assigns = Enum.into(assigns, %{is_proofing: false, is_finals: false})

    ~H"""
    <div class={"#{@class}"}>
      <%= live_redirect to: @route do %>
        <li class="group">
          <button class={"#{@button_class} flex items-center h-6 py-4 pl-12 w-full pr-6 overflow-hidden text-xs transition duration-300 ease-in-out rounded-lg text-ellipsis whitespace-nowrap group-hover:!text-blue-planning-300"}>
              <.icon name={@name} class={"w-4 h-4 stroke-2 fill-current #{@button_class} mr-2 group-hover:!text-blue-planning-300"}/>
              <%= if @is_finals, do: "Proofing " %>
              <%= if @is_proofing || @is_finals, do: String.capitalize(@title), else: @title %>
          </button>
        </li>
      <% end %>
    </div>
    """
  end

  defp get_select_photo_route(socket, albums, gallery, opts) do
    if Enum.empty?(albums) do
      Routes.gallery_photos_index_path(socket, :index, gallery, opts)
    else
      Routes.gallery_albums_index_path(socket, :index, gallery, opts)
    end
  end

  defp is_selected_album(album, selected_album),
    do: selected_album && album.id == selected_album.id

  defp icon_name(album) do
    cond do
      album.is_proofing -> "proofing"
      album.is_finals -> "finals"
      album.is_client_liked -> "heart-filled"
      true -> "standard_album"
    end
  end
end
