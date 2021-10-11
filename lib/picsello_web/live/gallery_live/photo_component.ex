defmodule PicselloWeb.GalleryLive.PhotoComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    {:ok, photo} = 
      Galleries.get_photo(id)
      |> Galleries.mark_photo_as_liked()

    {:noreply, assign(socket, :photo, photo)}
  end
end
