defmodule PicselloWeb.GalleryLive.ClientShow.Login do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias PicselloWeb.GalleryLive.ClientShow.AuthenticationComponent
  alias Picsello.Galleries

  @impl true
  def handle_params(%{"hash" => hash}, _, socket) do
    socket
    |> open_modal(AuthenticationComponent, %{gallery: Galleries.get_gallery_by_hash(hash)})
    |> noreply()
  end
end
