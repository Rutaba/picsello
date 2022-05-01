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
          gallery: gallery,
          arrow_show: arrow_show,
          album_dropdown_show: album_dropdown_show
        } = params,
        socket
      ) do
    albums = Albums.get_albums_by_gallery_id(gallery.id)

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery_progress:#{gallery.id}")
    end

    album = Map.get(params, :selected_album, nil)
    album_id = if !is_nil(album), do: album.id

    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "upload_update",
      {:upload_update, %{album_id: album_id}}
    )

    {:ok,
     socket
     |> assign(:id, id)
     |> assign(:total_progress, total_progress || 0)
     |> assign(:gallery, gallery)
     |> assign(:albums, albums)
     |> assign(:arrow_show, arrow_show)
     |> assign(:album_dropdown_show, album_dropdown_show)
     |> assign(:selected_album, album)
     |> assign_gallery_changeset()}
  end

  @impl true
  def handle_event("validate", %{"gallery" => %{"name" => name}}, socket) do
    socket
    |> assign_gallery_changeset(%{name: name})
    |> noreply
  end

  @impl true
  def handle_event("save", %{"gallery" => %{"name" => name}}, socket) do
    %{assigns: %{gallery: gallery, arrow_show: arrow}} = socket
    {:ok, gallery} = Galleries.update_gallery(gallery, %{name: name})

    arrow == "overview" && send(self(), {:update_name, %{gallery: gallery}})

    socket
    |> assign(:gallery, gallery)
    |> noreply
  end

  @impl true
  def handle_event(
        "select_overview",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_index_path(socket, :index, gallery))
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_unsorted_photos",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery))
    |> noreply()
  end

  @impl true
  def handle_event(
        "select_photos",
        _,
        %{
          assigns: %{
            gallery: gallery,
            albums: albums
          }
        } = socket
      ) do
    if Enum.empty?(albums) do
      socket
      |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery))
      |> noreply()
    else
      socket
      |> push_redirect(to: Routes.gallery_albums_index_path(socket, :index, gallery))
      |> noreply()
    end
  end

  @impl true
  def handle_event(
        "select_albums",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_albums_index_path(socket, :index, gallery))
    |> noreply()
  end

  @impl true
  def handle_event(
        "select_preview",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_product_preview_index_path(socket, :index, gallery))
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_album_selected",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> assign(:selected_item, "go_to_album")
    |> push_redirect(to: Routes.gallery_photos_index_path(socket, :index, gallery.id, album_id))
    |> noreply()
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
    album_dropdown_updated =
      case album_dropdown_show do
        false -> true
        true -> false
      end

    socket
    |> assign(:album_dropdown_show, album_dropdown_updated)
    |> noreply()
  end

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket),
    do: socket |> assign(:changeset, Galleries.change_gallery(gallery))

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket, attrs),
    do: socket |> assign(:changeset, Galleries.change_gallery(gallery, attrs))

  defp is_selected_album(album, selected_album),
    do: selected_album && album.id == selected_album.id
end
