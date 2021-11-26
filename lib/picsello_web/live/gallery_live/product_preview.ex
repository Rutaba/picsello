defmodule PicselloWeb.GalleryLive.ProductPreview do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  require Logger
  import Ecto.Changeset
  alias Picsello.Repo
  alias Picsello.Galleries
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.GalleriesCovers

  @per_page 12

  @impl true
  def mount(%{"id" => gallery_id, "gallery_cover_id" => gallery_cover_id}, _session, socket) do
    gallery = Repo.get_by(Gallery, %{id: gallery_id})

    gallery_cover_id =
      (is_binary(gallery_cover_id) && String.to_integer(gallery_cover_id)) || gallery_cover_id

    preview =
      Repo.get_by(GalleriesCovers, %{:gallery_id => gallery_id, :id => gallery_cover_id})
      |> Repo.preload([:photo])

    if nil in [preview, gallery] do
      gallery == nil &&
        Logger.error("not found row with gallery_id: #{gallery_id} in galleries table")

      preview == nil &&
        Logger.error(
          "not found row with gallery_cover_id: #{gallery_cover_id} in galleries_covers table"
        )

      {:ok, redirect(socket, to: "/")}
    else
      url = preview.photo.preview_url || nil

      {:ok, socket |> assign(:preview, url)}
    end
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.GalleriesCovers{}, data, prop)
  end

  @impl true
  def handle_event("load-more", _, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(page: page + 1)
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end

  def handle_event("set_preview", %{"photo_id" => photo_id}, socket) do
    socket
      |> assign(:photo_id, photo_id)
      |> noreply
  end

  def handle_event("save", %{"galleries_covers" => %{"photo_id" => photo_id}},
    %{assigns:
      %{gallery_cover_id: cover_id,
        gallery: %{id: gallery_id}}} = socket) do

    [photo_id, cover_id, gallery_id] =
      Enum.map(
        [photo_id, cover_id, gallery_id],
        fn x ->
          (is_binary(x) && String.to_integer(x)) || x
        end
      )

    fields = %{gallery_id: gallery_id, id: cover_id}

    result = Repo.get_by(GalleriesCovers, fields)

    if result != nil do
      result
      |> cast(%{photo_id: photo_id}, [:photo_id])
      |> Repo.insert_or_update()
    end

    {:noreply, socket}
  end

  def handle_event(ev, data, socket) do
    Logger.error("unhandled event #{ev} in #{__MODULE__} with #{data} data")
    {:noreply, socket}
  end

  @impl true
  def handle_params(%{"id" => id, "gallery_cover_id" => gallery_cover_id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    gallery_cover_id =
      (is_binary(gallery_cover_id) && String.to_integer(gallery_cover_id)) || gallery_cover_id

    if Repo.get_by(GalleriesCovers, %{:id => gallery_cover_id}) == nil do
      {:noreply, redirect(socket, to: "/")}
    else
      socket
      |> assign(:gallery, gallery)
      |> assign(:gallery_cover_id, gallery_cover_id)
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
  end

  # @impl true
  # def handle_info(
  #       {:photo_processed, %{"task" => %{"photoId" => photo_id}}},
  #       %{assigns: %{modal_pid: modal_pid}} = socket
  #     ) do
  #   send_update(modal_pid, UploadComponent, id: UploadComponent, a_photo_processed: photo_id)

  #   noreply(socket)
  # end

  # def handle_cover_progress(:cover_photo, entry, %{assigns: assigns} = socket) do
  #   if entry.done? do
  #     {:ok, gallery} =
  #       Galleries.update_gallery(assigns.gallery, %{
  #         cover_photo_id: entry.uuid,
  #         cover_photo_aspect_ratio: 1
  #       })

  #     {:noreply, socket |> assign(:gallery, gallery)}
  #   else
  #     {:noreply, socket}
  #   end
  # end

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{id: id},
             page: page,
             favorites_filter: filter
           }
         } = socket
       ) do
    assign(socket,
      photos: Galleries.get_gallery_photos(id, @per_page, page, only_favorites: filter)
    )
  end

  # def presign_cover_entry(entry, socket) do
  #   key = entry.uuid

  #   sign_opts = [
  #     expires_in: 600,
  #     bucket: socket.assigns.upload_bucket,
  #     key: key,
  #     fields: %{
  #       "content-type" => entry.client_type,
  #       "cache-control" => "public, max-age=@upload_options"
  #     },
  #     conditions: [["content-length-range", 0, 104_857_600]]
  #   ]

  #   params = PhotoStorage.params_for_upload(sign_opts)
  #   meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

  #   {:ok, meta, socket}
  # end
end
