defmodule PicselloWeb.GalleryLive.Album do
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries
  alias Picsello.Galleries.Workers.PhotoStorage

  @per_page 12

  def mount(_params, _session, socket) do
    {:ok, socket}
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
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    socket
    |> assign(:gallery, gallery)
    |> assign(:page, 0)
    |> assign(:update_mode, "append")
    |> assign(:favorites_filter, false)
    |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
    |> assign_photos()
    # |> then(fn
    #   %{assigns: %{live_action: :upload}} = socket ->
    #     send(self(), :open_modal)
    #     socket

    #   socket ->
    #     socket
    # end)
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

  defp assign_photos(
    %{
      assigns: %{
        gallery: %{id: id},
        page: page,
        favorites_filter: filter
      }
    } = socket
  ) do
    IO.puts"_________________________________"
        IO.inspect @per_page
        IO.inspect page
assign(socket,
 photos: Galleries.get_gallery_photos(id, @per_page, page, only_favorites: filter)
)
end
  # def render(assigns) do
  #   IO.inspect(assigns)
  #   ~H"""
  #     ____PRODUCT____
  #   """
  # end
end
