defmodule PicselloWeb.GalleryLive.ClientShow.Login do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_gallery_client"]
  alias PicselloWeb.GalleryLive.ClientShow.AuthenticationComponent
  alias Picsello.{Galleries, Albums}

  @impl true
  def mount(%{"hash" => hash}, _session, socket) do
    socket
    |> assign(%{
      meta_attrs: %{
        robots: "noindex, nofollow"
      }
    })
    |> assigns(socket.assigns.live_action, hash)
    |> then(
      &open_modal(
        &1,
        AuthenticationComponent,
        %{
          background: "bg-gradient-to-t from-black/80 to-black-20",
          assigns: Map.take(&1.assigns, [:gallery, :album, :live_action])
        }
      )
    )
    |> ok()
  end

  defp assigns(socket, :gallery_login, hash) do
    assign_new(socket, :gallery, fn -> Galleries.get_gallery_by_hash(hash) end)
  end

  defp assigns(socket, :album_login, hash) do
    socket
    |> assign_new(:album, fn -> Albums.get_album_by_hash!(hash) end)
    |> then(
      &assign_new(&1, :gallery, fn -> Galleries.get_gallery!(&1.assigns.album.gallery_id) end)
    )
  end
end
