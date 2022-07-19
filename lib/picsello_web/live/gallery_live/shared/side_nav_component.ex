defmodule PicselloWeb.GalleryLive.Shared.SideNavComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Galleries, Albums}
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
    albums = Albums.get_albums_by_gallery_id(gallery.id)

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery_progress:#{gallery.id}")
      PubSub.subscribe(Picsello.PubSub, "photos_error:#{gallery.id}")
      PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery.id}")
    end

    album = Map.get(params, :selected_album, nil)
    album_id = if !is_nil(album), do: album.id

    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "upload_update:#{gallery.id}",
      {:upload_update, %{album_id: album_id}}
    )

    socket
    |> assign(:id, id)
    |> assign(:total_progress, total_progress)
    |> assign(:photos_error_count, photos_error_count)
    |> assign(:gallery, gallery)
    |> assign(:edit_name, true)
    |> assign(:is_mobile, is_mobile)
    |> assign(:albums, albums)
    |> assign(:arrow_show, arrow_show)
    |> assign(:album_dropdown_show, album_dropdown_show)
    |> assign(:selected_album, album)
    |> assign_gallery_changeset()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"gallery" => %{"name" => name}}, socket) do
    socket
    |> assign_gallery_changeset(%{name: name})
    |> noreply
  end

  @impl true
  def handle_event("click", _, socket) do
    socket
    |> assign(:edit_name, false)
    |> noreply
  end

  @impl true
  def handle_event("save", %{"gallery" => %{"name" => name}}, socket) do
    %{assigns: %{gallery: gallery, arrow_show: arrow}} = socket
    {:ok, gallery} = Galleries.update_gallery(gallery, %{name: name})

    arrow == "overview" && send(self(), {:update_name, %{gallery: gallery}})

    socket
    |> assign(:edit_name, true)
    |> assign(:gallery, gallery)
    |> noreply
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
        <div class="flex items-center lg:h-11 pr-4 lg:pl-2 lg:py-4 pl-3 py-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded text-ellipsis whitespace-nowrap hover:text-blue-planning-300">
          <div class="flex items-center justify-center flex-shrink-0 w-8 h-8 rounded-full bg-blue-planning-300">
              <img src={Routes.static_path(PicselloWeb.Endpoint, "/images/#{@icon}")} width="16" height="16"/>
          </div>
          <div class="ml-3">
            <span class={@arrow_show && "text-blue-planning-300"}><%= @title %></span>
          </div>
          <div class="flex px-2 items-center ml-auto">
            <%= render_slot(@inner_block) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp li(assigns) do
    ~H"""
    <div class={"#{@class}"}>
      <%= live_redirect to: @route do %>
        <li>
          <button class={"#{@button_class} flex items-center h-6 py-4 pl-12 w-full pr-6 overflow-hidden text-xs transition duration-300 ease-in-out rounded-lg text-ellipsis whitespace-nowrap hover:text-blue-planning-300"}><%= @title%></button>
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

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket),
    do:
      socket
      |> assign(:changeset, Galleries.change_gallery(gallery) |> Map.put(:action, :validate))

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket, attrs),
    do:
      socket
      |> assign(
        :changeset,
        Galleries.change_gallery(gallery, attrs) |> Map.put(:action, :validate)
      )

  defp is_selected_album(album, selected_album),
    do: selected_album && album.id == selected_album.id
end
