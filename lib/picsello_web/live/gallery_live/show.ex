defmodule PicselloWeb.GalleryLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Repo
  alias Picsello.Galleries
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Picsello.Galleries.Workers.PositionNormalizer
  alias Picsello.Galleries.GalleryProduct
  alias PicselloWeb.GalleryLive.UploadComponent
  alias PicselloWeb.GalleryLive.DeletePhoto
  alias PicselloWeb.GalleryLive.PhotoComponent

  @per_page 12
  @upload_options [
    accept: ~w(.jpg .jpeg .png),
    max_entries: 1,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &__MODULE__.presign_cover_entry/2,
    progress: &__MODULE__.handle_cover_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:upload_bucket, @bucket)
     |> allow_upload(:cover_photo, @upload_options)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id)
    preview =
      Repo.get_by(GalleryProduct, %{:gallery_id => id})
      |> Repo.preload([:preview_photo, :category_template])

    data = Repo.all(Picsello.CategoryTemplates)

    template_name2 = Enum.at(data, 1) |> Map.get(:name)
    template_name3 = Enum.at(data, 2) |> Map.get(:name)
    template_name4 = Enum.at(data, 3) |> Map.get(:name)
    template_coords = Enum.map(data, fn x -> Map.get(x, :corners) end)

    url = if preview != nil and Map.has_key?(preview, :preview_photo) do
      preview.preview_photo != nil &&
      PicselloWeb.GalleryLive.GalleryProduct.path(preview.preview_photo.preview_url) || "/images/card_blank.png"
    else "/images/card_blank.png" end

    event_datas = Enum.map(0..3, fn x -> %{
      preview: url,
      frame: Map.get(Enum.at(data, x), :name),
      coords: Map.get(Enum.at(data, x), :corners),
      target: "canvas#{x}"}
    end)

    preview_id = if preview == nil do 1 else preview.id end

    socket
    |> assign(:templates, Enum.with_index(data))
    |> assign(:gallery_product_id, preview_id)
    |> assign(:preview, cover_photo(url))
    |> push_event("set_preview", Enum.at(event_datas, 0))
    |> push_event("set_preview", Enum.at(event_datas, 1))
    |> push_event("set_preview", Enum.at(event_datas, 2))
    |> push_event("set_preview", Enum.at(event_datas, 3))
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:gallery, gallery)
    |> assign(:page, 0)
    |> assign(:update_mode, "append")
    |> assign(:favorites_filter, false)
    |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
    |> assign_photos()
    |> then(fn
      %{assigns: %{live_action: :upload}} = socket ->
        send(self(), :open_modal)
        socket

      socket ->
        socket
    end)
    |> noreply()
  end

  @impl true
  def handle_event("start", _params, socket) do
    socket.assigns.uploads.cover_photo
    |> case do
      %{valid?: false, ref: ref} -> {:noreply, cancel_upload(socket, :cover_photo, ref)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_upload_popup", _, socket) do
    send(self(), :open_modal)
    socket |> noreply()
  end

  @impl true
  def handle_event("load-more", _, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(page: page + 1)
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event("toggle_favorites", _, %{assigns: %{favorites_filter: toggle_state}} = socket) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, !toggle_state)
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event(
        "update_photo_position",
        %{"photo_id" => photo_id, "type" => type, "args" => args},
        %{assigns: %{gallery: %{id: gallery_id}}} = socket
      ) do
    Galleries.update_gallery_photo_position(
      gallery_id,
      photo_id |> String.to_integer(),
      type,
      args
    )

    PositionNormalizer.normalize(gallery_id)

    noreply(socket)
  end

  @impl true
  def handle_event("delete_cover_photo_popup", _, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> open_modal(DeletePhoto, %{gallery_name: gallery.name, type: :cover})
    |> noreply()
  end

  @impl true
  def handle_event("delete_photo_popup", %{"id" => id}, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> open_modal(DeletePhoto, %{gallery_name: gallery.name, type: :plain, photo_id: id})
    |> noreply()
  end

  @impl true
  def handle_event("client-link", _, %{assigns: %{gallery: gallery}} = socket) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    socket
    |> push_redirect(to: Routes.gallery_client_show_path(socket, :show, hash))
    |> noreply()
  end

  @impl true
  def handle_info(
        {:photo_processed, %{"task" => %{"photoId" => photo_id}}},
        %{assigns: %{modal_pid: modal_pid}} = socket
      ) do
    send_update(modal_pid, UploadComponent, id: UploadComponent, a_photo_processed: photo_id)

    noreply(socket)
  end

  def handle_info({:photo_processed, _}, socket), do: noreply(socket)

  @impl true
  def handle_info(:confirm_cover_photo_deletion, %{assigns: %{gallery: gallery}} = socket) do
    {:ok, gallery} = Galleries.update_gallery(gallery, %{cover_photo_id: nil})

    socket
    |> assign(:gallery, gallery)
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info({:confirm_photo_deletion, id}, %{assigns: %{gallery: gallery}} = socket) do
    Galleries.get_photo(id) |> Galleries.delete_photo()
    {:ok, gallery} = Galleries.update_gallery(gallery, %{total_count: gallery.total_count - 1})

    send_update(PhotoComponent, id: String.to_integer(id), is_removed: true)

    socket
    |> assign(:gallery, gallery)
    |> close_modal()
    |> push_event("remove_item", %{"id" => id})
    |> noreply()
  end

  @impl true
  def handle_info(:cancel_photo_deletion, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  def handle_info(:open_modal, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> open_modal(UploadComponent, %{gallery: gallery})
    |> noreply()
  end

  def handle_info(:close_upload_popup, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  def handle_info({:photo_upload_completed, _count}, %{assigns: %{gallery: gallery}} = socket) do
    Galleries.update_gallery_photo_count(gallery.id)

    Galleries.normalize_gallery_photo_positions(gallery.id)

    socket
    |> push_redirect(to: Routes.gallery_show_path(socket, :show, gallery.id))
    |> noreply()
  end

  def handle_cover_progress(:cover_photo, entry, %{assigns: assigns} = socket) do
    if entry.done? do
      {:ok, gallery} =
        Galleries.update_gallery(assigns.gallery, %{
          cover_photo_id: entry.uuid,
          cover_photo_aspect_ratio: 1
        })

      {:noreply, socket |> assign(:gallery, gallery)}
    else
      {:noreply, socket}
    end
  end

  def presign_cover_entry(entry, socket) do
    key = entry.uuid

    sign_opts = [
      expires_in: 600,
      bucket: socket.assigns.upload_bucket,
      key: key,
      fields: %{
        "content-type" => entry.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, 104_857_600]]
    ]

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{id: id},
             page: page,
             favorites_filter: filter
           }
         } = socket,
         per_page \\ @per_page
       ) do
    opts = [only_favorites: filter, offset: per_page * page]
    photos = Galleries.get_gallery_photos(id, per_page + 1, page, opts)

    socket
    |> assign(:photos, photos |> Enum.take(per_page))
    |> assign(:has_more_photos, photos |> length > per_page)
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"
  defp page_title(:upload), do: "New Gallery"

  defp cover_photo(key) do
    PhotoStorage.path_to_url(key)
  end
end
