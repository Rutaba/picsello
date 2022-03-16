defmodule PicselloWeb.GalleryLive.Albums do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries.Album
  alias Picsello.Galleries
  alias Picsello.Repo

  @impl true
  def mount(%{"gallery_id" => gallery_id}, _session, socket) do
    gallery = Galleries.get_gallery!(gallery_id) |> Repo.preload(:albums)

    {
      :ok,
      socket
      |> assign(:gallery_id, gallery_id)
      |> assign(:gallery, gallery)
      |> assign(:upload_toast, "hidden")
      |> assign(:selected_item, nil)
    }
  end

  @impl true
  def handle_params(%{"upload_toast" => upload_toast} = _params, _uri, socket) do
    socket
    |> assign(:upload_toast, upload_toast)
    |> noreply()
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    noreply(socket)
  end

  @impl true
  def handle_event("upload_toast", _, socket) do
    socket
    |> assign(:upload_toast, "hidden")
    |> noreply()
  end

  @impl true
  def handle_event(
        "open_albums_popup",
        %{},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    socket
    |> open_modal(PicselloWeb.GalleryLive.Settings.AddAlbumModal, %{gallery_id: gallery_id})
    |> noreply()
  end

  @impl true
  def handle_event(
        "clear_selected",
        %{},
        socket
      ) do
    socket
    |> assign(:selected_item, nil)
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_album_selected",
        %{},
        %{
          assigns: %{
          }
        } = socket
      ) do
    socket
    |> assign(:selected_item, "go_to_album")
    |> noreply()
  end

  @impl true
  def handle_event(
        "share_album_selected",
        %{},
        %{
          assigns: %{
          }
        } = socket
      ) do
    socket
    |> assign(:selected_item, "share_album")
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit_album_thumbnail_selected",
        %{},
        %{
          assigns: %{
          }
        } = socket
      ) do
    socket
    |> assign(:selected_item, "edit_album_thumbnail")
    |> noreply()
  end

  @impl true
  def handle_event(
        "go_to_album_settings_selected",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery_id: gallery_id
          }
        } = socket
      ) do
    album = Repo.get!(Album, album_id)
    socket
    |> assign(:selected_item, "go_to_album_settings")
    |> open_modal(PicselloWeb.GalleryLive.Albums.AlbumSettingsModal, %{gallery_id: gallery_id, album: album})
    |> noreply()
  end
end
