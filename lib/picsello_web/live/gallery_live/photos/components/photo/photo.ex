defmodule PicselloWeb.GalleryLive.Photos.Photo do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Photos
  alias PicselloWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS
  
  import PicselloWeb.GalleryLive.Shared, only: [original_album_link: 2]
  import PicselloWeb.GalleryLive.Photos.Photo.Shared

  @impl true
  def update(%{photo: photo} = assigns, socket) do
    socket
    |> assign(
      album_name: Photos.get_album_name(photo),
      preview_photo_id: nil,
      is_likable: false,
      is_removable: false,
      is_viewable: false,
      is_meatball: false,
      is_gallery_category_page: false,
      album: nil,
      component: false,
      selected_photo_id: nil,
      is_proofing: assigns[:is_proofing] || false,
      client_link_hash: Map.get(assigns, :client_link_hash),
      is_liked: photo.is_photographer_liked,
      url: Routes.static_path(PicselloWeb.Endpoint, "/images/gallery-icon.svg")
    )
    |> assign(assigns)
    |> ok
  end

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    {:ok, _} = Photos.toggle_photographer_liked(id)

    socket |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_original_album",
        params,
        %{
          assigns: %{
            photo: photo,
            is_mobile: is_mobile
          }
        } = socket
      ) do
    is_mobile = if(is_mobile, do: [], else: [is_mobile: false])
    album = params["album"]

    route =
      if(is_nil(album),
        do: Routes.gallery_photos_index_path(socket, :index, photo.gallery_id, is_mobile),
        else:
          Routes.gallery_photos_index_path(
            socket,
            :index,
            photo.gallery_id,
            album,
            is_mobile
          )
      )

    socket
    |> push_redirect(to: route)
    |> noreply()
  end

  defp photo_wrapper(assigns) do
    ~H"""
    <div id={"img-#{@id}"} class="galleryItem" data-selected_photo_id={"img-#{@selected_photo_id}"} phx-click="toggle_selected_photos" phx-value-photo_id={@id} phx-hook="GallerySelector">
        <div id={"photo-#{@id}-selected"} photo-id={@id} class="toggle-it"></div>
        <%= render_block(@inner_block) %>
    </div>
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

  defp toggle_border(js \\ %JS{}, id, is_gallery_category_page) do
    if is_gallery_category_page do
      js
      |> JS.dispatch("click", to: "#photo-#{id} > img")
      |> JS.add_class("item-border", to: "#item-#{id}")
    else
      js |> JS.dispatch("click", to: "#photo-#{id} > img")
    end
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

  defp actions(assigns) do
    ~H"""
    <div id={@id} class={"absolute #{@class}"} phx-click={@event} phx-value-photo_id={@photo_id}>
      <.icon name={@icon} class="h-6 text-white w-7"/>
    </div>
    """
  end

  defp album_name(assigns) do
    cond do
      assigns.album_name -> assigns.album_name
      assigns.albums_length == 1 -> "All photos"
      true -> "Unsorted photos"
    end
  end
end
