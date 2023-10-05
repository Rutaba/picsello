defmodule PicselloWeb.GalleryLive.Shared.SideNavComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared
  import Picsello.Utils, only: [products_currency: 0]
  import Picsello.Albums, only: [get_all_albums_photo_count: 1]

  alias Picsello.Galleries
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
    total_count =
      if is_total_progress_idle?(total_progress),
        do: Galleries.get_gallery_photo_count(gallery.id),
        else: nil

    unsorted_count =
      if is_total_progress_idle?(total_progress),
        do: Galleries.get_gallery_unsorted_photo_count(gallery.id),
        else: nil

    albums =
      get_all_gallery_albums(gallery.id)
      |> maybe_album_map_count(total_progress, gallery.id)

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
    |> assign(:edit_name, true)
    |> assign(:is_mobile, is_mobile)
    |> assign(:albums, albums)
    |> assign(:unsorted_count, unsorted_count)
    |> assign(:total_count, total_count)
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
    assigns = Enum.into(assigns, %{is_proofing: false, is_finals: false, photos_count: nil})

    ~H"""
    <div class={"#{@class}"}>
      <%= live_redirect to: @route do %>
        <li class="group">
          <button class={"#{@button_class} flex items-center justify-between h-6 py-4 pl-12 w-full pr-6 overflow-hidden text-xs transition duration-300 ease-in-out rounded-lg text-ellipsis whitespace-nowrap group-hover:!text-blue-planning-300"}>
              <div class="flex items-center justify-between">
                <.icon name={@name} class={"w-4 h-4 stroke-2 fill-current #{@button_class} mr-2 group-hover:!text-blue-planning-300"}/>
                <%= if @is_finals, do: "Proofing " %>
                <%= if @is_proofing || @is_finals, do: String.capitalize(@title), else: @title %>
              </div>
              <%= if @photos_count do %>
                <.photo_count photos_count={@photos_count} />
              <% end %>
          </button>
        </li>
      <% end %>
    </div>
    """
  end

  defp photo_count(assigns) do
    assigns = Enum.into(assigns, %{photos_count: 0})

    ~H"""
      <span class="bg-white px-1 py-0.5 rounded-full min-w-[30px] font-normal text-xs flex items-center justify-center ml-auto"><%= @photos_count %></span>
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

  defp icon_name(album) do
    cond do
      album.is_proofing -> "proofing"
      album.is_finals -> "finals"
      album.is_client_liked -> "heart-filled"
      true -> "standard_album"
    end
  end

  defp is_total_progress_idle?(total_progress) do
    total_progress == 0 || total_progress == 100
  end

  defp maybe_album_map_count(albums, total_progress, gallery_id) do
    if is_total_progress_idle?(total_progress) do
      albums_count = get_all_albums_photo_count(gallery_id)

      albums
      |> Enum.map(
        &Map.put(
          &1,
          :photos_count,
          Enum.filter(albums_count, fn %{album_id: album_id, count: _} ->
            album_id == &1.id
          end)
          |> List.first()
          |> Map.get(:count, 0)
        )
      )
    else
      albums
    end
  end
end
