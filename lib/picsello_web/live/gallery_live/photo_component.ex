defmodule PicselloWeb.GalleryLive.PhotoComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries
  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.Workers.PhotoStorage

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    {:ok, photo} =
      Galleries.get_photo(id)
      |> Galleries.mark_photo_as_liked()

    favorites_update =
      if photo.client_liked,
        do: :increase_favorites_count,
        else: :reduce_favorites_count

    send(self(), favorites_update)

    {:noreply, assign(socket, :photo, photo)}
  end

  @impl true
  def handle_event("click", _, %{assigns: %{photo: photo}} = socket) do
    send(self(), {:photo_click, photo})

    socket
    |> noreply()
  end

  defp display(%Photo{} = photo) do
    display(photo.watermarked_preview_url || photo.preview_url)
  end

  defp display(nil), do: "/images/gallery-icon.png"

  defp display(key) do
    PhotoStorage.path_to_url(key)
  end
end
