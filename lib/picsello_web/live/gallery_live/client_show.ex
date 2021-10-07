defmodule PicselloWeb.GalleryLive.ClientShow do
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries
  alias Picsello.Galleries.{Gallery, Photo}
  alias Picsello.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"hash" => hash}, _, socket) do
    gallery = Galleries.get_gallery_by_hash(hash)

    if gallery do
      {:noreply,
       socket
       |> assign(:page_title, page_title(socket.assigns.live_action))
       |> assign(:hash, hash)
       |> assign(:gallery, gallery |> Repo.preload([:photos, :cover_photo]))}
    else
      {:noreply, socket}
    end
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"
end
