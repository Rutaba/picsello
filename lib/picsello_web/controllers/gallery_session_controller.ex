defmodule PicselloWeb.GallerySessionController do
  use PicselloWeb, :controller

  alias Picsello.Galleries
  alias Picsello.Repo

  def gallery_login(conn, %{"hash" => hash, "login" => %{"session_token" => token}}) do
    gallery =
      hash
      |> Galleries.get_gallery_by_hash!()
      |> Repo.preload([:albums])

    conn
    |> put_session("gallery_session_token", token)
    |> redirect_to(gallery)
  end

  defp redirect_to(conn, %{type: :standard, client_link_hash: hash}) do
    redirect(conn, to: Routes.gallery_client_index_path(conn, :index, hash))
  end

  defp redirect_to(conn, %{albums: [%{client_link_hash: hash}]}) do
    redirect(conn, to: Routes.gallery_client_album_path(conn, :proofing_album, hash))
  end
end
