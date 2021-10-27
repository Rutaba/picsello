defmodule PicselloWeb.GalleryLive.PhotoComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

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

  # def handle_event("remove", %{"id" => id}, socket) do
  # some removing item logic
  # end
end
