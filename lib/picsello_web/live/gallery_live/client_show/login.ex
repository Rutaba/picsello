defmodule PicselloWeb.GalleryLive.ClientShow.Login do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias PicselloWeb.GalleryLive.ClientShow.AuthenticationComponent
  alias Picsello.Galleries

  @impl true
  def mount(%{"hash" => hash}, _session, socket) do

    socket
    |> assign_new(:gallery, fn -> Galleries.get_gallery_by_hash(hash) end)
    |> then(&open_modal(&1, AuthenticationComponent, Map.take(&1.assigns, [:gallery])))
    |> ok()
  end
end
