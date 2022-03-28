defmodule PicselloWeb.GalleryLive.Shared.SideNavComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries
  alias Picsello.Repo

  @impl true
  def update(
        %{id: id, gallery: gallery, total_progress: total_progress, arrow_show: arrow_show},
        socket
      ) do
    gallery = Repo.preload(gallery, :albums)
    {:ok,
     socket
     |> assign(:id, id)
     |> assign(:total_progress, total_progress || 0)
     |> assign(:gallery, gallery)
     |> assign(:arrow_show, arrow_show)
     |> assign(:album_dropdown_show, false)
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
    %{assigns: %{gallery: gallery}} = socket
    {:ok, gallery} = Galleries.update_gallery(gallery, %{name: name})

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
    |> push_redirect(to: Routes.gallery_overview_path(socket, :overview, gallery))
    |> noreply()
  end

  @impl true
  def handle_event(
        "select_photos",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_photos_path(socket, :show, gallery))
    |> noreply()
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
    |> push_redirect(to: Routes.gallery_albums_path(socket, :albums, gallery))
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
    |> push_redirect(to: Routes.gallery_photos_main_path(socket, :show, gallery))
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
    |> push_redirect(to: Routes.gallery_album_path(socket, :show, gallery.id, album_id))
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
end
