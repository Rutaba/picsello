defmodule PicselloWeb.GalleryLive.Photos.Main do
  @moduledoc false
  use PicselloWeb,
      live_view: [
        layout: "live_client"
      ]

  import PicselloWeb.LiveHelpers

  alias Phoenix.PubSub
  alias Picsello.Repo
  alias Picsello.{Galleries, Messages}
  alias Picsello.Galleries.{Photo, CoverPhoto}
  alias Picsello.Galleries.Workers.{PhotoStorage, PositionNormalizer}
  alias Picsello.Notifiers.ClientNotifier
  alias Picsello.Galleries.PhotoProcessing.{ProcessingManager, GalleryUploadProgress}
  alias PicselloWeb.GalleryLive.{UploadComponent, ViewPhoto}
  alias PicselloWeb.ConfirmationComponent
  alias PicselloWeb.GalleryLive.Photos.PhotoComponent
  alias PicselloWeb.GalleryLive.Photos.ProductPreview

  @per_page 24
  @upload_options [
    accept: ~w(.jpg .jpeg .png image/jpeg image/png),
    max_entries: 1500,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &__MODULE__.presign_entry/2,
    progress: &__MODULE__.handle_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:upload_bucket, @bucket)
      |> assign(:overall_progress, 0)
      |> assign(:estimate, "n/a")
      |> assign(:uploaded_files, 0)
      |> assign(:progress, %GalleryUploadProgress{})
      |> assign(:photo_updates, "false")
      |> assign(:select_mode, "selected_none")
      |> assign(:update_mode, "append")
      |> assign(:selected_photos, [])
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id) |> Repo.preload(:albums)

    if connected?(socket), do: PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery.id}")

    socket
    |> assign(
         gallery_id: id,
         favorites_count: Galleries.gallery_favorites_count(gallery),
         favorites_filter: false,
         gallery: gallery,
         page: 0,
         page_title: page_title(socket.assigns.live_action),
         products: Galleries.products(gallery)
       )
    |> assign_photos()
    |> then(fn
      %{
        assigns: %{
          live_action: :upload
        }
      } = socket ->
        send(self(), :open_modal)
        socket

      socket ->
        socket
    end)
    |> noreply()
  end

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{
               id: id
             },
             page: page,
             favorites_filter: filter
           }
         } = socket,
         per_page \\ @per_page
       ) do
    opts = [only_favorites: filter, exclude_album: true, offset: per_page * page]
    photos = Galleries.get_gallery_photos(id, per_page + 1, page, opts)

    socket
    |> assign(
         :photos,
         photos
         |> Enum.take(per_page)
       )
    |> assign(
         :has_more_photos,
         photos
         |> length > per_page
       )
  end

  @impl true
  def handle_event("edit_product", %{"category_id" => gallery_product_id}, %{assigns: %{gallery_id: gallery_id}} = socket) do
#    IO.puts("\n\n########## DEBUG ##########\n sock #{inspect(socket, pretty: true)} \n########## DEBUG ##########\n\n")
    socket
    |> open_modal(
         PicselloWeb.GalleryLive.Photos.EditProduct,
         %{gallery_product_id: gallery_product_id,
           gallery_id: gallery_id
         }
       )
    |> noreply
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"
  defp page_title(:upload), do: "New Gallery"

end
