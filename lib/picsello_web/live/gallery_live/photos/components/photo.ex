defmodule PicselloWeb.GalleryLive.Photos.Photo do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Phoenix.LiveView.JS
  alias Picsello.Photos
  alias PicselloWeb.Router.Helpers, as: Routes

  import PicselloWeb.GalleryLive.Shared, only: [original_album_link: 2]

  @impl true
  def update(%{photo: photo} = assigns, socket) do
    album = Map.get(assigns, :album)
    album_name = Photos.get_album_name(photo)

    socket
    |> assign(
      album_name: album_name,
      preview_photo_id: nil,
      is_likable: false,
      is_removable: false,
      is_viewable: false,
      is_meatball: false,
      proofing_photo_icons: if(album && album.is_proofing, do: false, else: true),
      is_gallery_category_page: false,
      is_client_gallery: false,
      album: nil,
      component: false,
      selected_photo_id: nil,
      client_liked_album: false,
      is_proofing: assigns[:is_proofing] || false,
      client_link_hash: Map.get(assigns, :client_link_hash),
      url: Routes.static_path(PicselloWeb.Endpoint, "/images/gallery-icon.svg")
    )
    |> assign(assigns)
    |> then(fn
      %{assigns: %{is_client_gallery: true}} = socket ->
        assign(socket, :is_liked, photo.client_liked)

      socket ->
        assign(socket, :is_liked, photo.photographer_liked)
    end)
    |> ok
  end

  @impl true
  def handle_event(
        "like",
        %{"id" => id},
        %{assigns: %{is_client_gallery: is_client_gallery}} = socket
      ) do
    {:ok, _} =
      case is_client_gallery do
        true -> Photos.toggle_liked(id)
        false -> Photos.toggle_photographer_liked(id)
      end

    socket |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_original_album",
        %{"album" => album_id},
        %{
          assigns: %{
            photo: photo,
            is_mobile: is_mobile
          }
        } = socket
      ) do
    is_mobile = if(is_mobile, do: [], else: [is_mobile: false])

    socket
    |> push_redirect(
      to: Routes.gallery_photos_index_path(socket, :index, photo.gallery_id, album_id, is_mobile)
    )
    |> noreply()
  end

  defp toggle_border(js \\ %JS{}, id, is_gallery_category_page) do
    if is_gallery_category_page do
      js
      |> JS.dispatch("click", to: "#photo-#{id} > img")
      |> JS.add_class("item-border", to: "#item-#{id}")
    else
      js |> JS.dispatch("click", to: "#photo-#{id} > img")
    end
  end

  defp js_like_click(js \\ %JS{}, id, target) do
    js
    |> JS.push("like", target: target, value: %{id: id})
    |> JS.toggle(to: "#photo-#{id}-liked")
    |> JS.toggle(to: "#photo-#{id}-to-like")
  end

  defp meatball(album, id) do
    if album && !album.is_client_liked do
      [
        %{
          id: "photo-thumbnail-#{id}",
          event: "set_album_thumbnail_popup",
          title: "Set as album thumbnail"
        },
        %{id: "photo-remove-#{id}", event: "remove_from_album_popup", title: "Remove from album"}
      ]
    else
      [
        %{id: "photo-remove-#{id}", event: "photo_view", title: "View"}
      ]
    end ++
      [
        %{id: "photo-preview-#{id}", event: "photo_preview_pop", title: "Set as product preview"}
      ]
  end

  defp photo_wrapper(assigns) do
    ~H"""
    <%= if @is_client_gallery do %>
      <div id={"img-#{@id}"} class="galleryItem" phx-click="click" phx-value-preview_photo_id={@id}>
      <%= render_block(@inner_block) %>
      </div>
    <% else %>
        <div id={"img-#{@id}"} class="galleryItem" data-selected_photo_id={@selected_photo_id} phx-click="toggle_selected_photos" phx-value-photo_id={@id} phx-hook="GallerySelector">
            <div id={"photo-#{@id}-selected"} photo-id={@id} class="toggle-it"></div>
            <%= render_block(@inner_block) %>
        </div>
    <% end%>
    """
  end

  defp photo(%{target: false} = assigns) do
    ~H"""
    <img src={@url} class="relative" />
    """
  end

  defp photo(assigns) do
    ~H"""
    <img phx-click="click" phx-target={@target} phx-value-preview={@preview} phx-value-preview_photo_id={@photo_id} src={@url} class="relative" />
    """
  end

  defp ul(assigns) do
    ~H"""
    <ul class="absolute hidden bg-white pl-1 py-1 rounded-md popover-content meatballsdropdown w-40 overflow-visible">
      <%= for li <- @entries do %>
      <li class="flex items-center hover:bg-blue-planning-100 hover:rounded-md">
        <div id={li.id} class="hover-drop-down" phx-click={li.event} phx-value-photo_id={@id}>
          <%= li.title %>
        </div>
      </li>
      <% end %>
      <li class="flex items-center hover:bg-blue-planning-100 hover:rounded-md">
        <a id={"download-photo-#{@id}"} class="hover-drop-down"
          download
          href={Routes.gallery_downloads_path(
            @socket,
            :download_photo,
            @client_link_hash,
            @id
          )}>Download photo
        </a>
      </li>
      <%= if @album && @album.is_client_liked do %>
        <li class="flex items-center hover:bg-blue-planning-100 hover:rounded-md">
          <%=
            live_redirect(
            "Go to original",
            to: original_album_link(@socket, @photo),
            class: "hover-drop-down"
            )
          %>
        </li>
      <% end %>
    </ul>
    """
  end

  defp actions(assigns) do
    ~H"""
    <div id={@id} class={"absolute #{@class}"} phx-click={@event} phx-value-photo_id={@photo_id}>
      <.icon name={@icon} class="h-6 text-white w-7"/>
    </div>
    """
  end

  defp wrapper_style(true, width, %{aspect_ratio: aspect_ratio}),
    do: "width: #{width}px;height: #{width / aspect_ratio}px;"

  defp wrapper_style(_, _, _), do: nil
end
