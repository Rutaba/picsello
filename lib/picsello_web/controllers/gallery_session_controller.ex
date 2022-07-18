defmodule PicselloWeb.GallerySessionController do
  use PicselloWeb, :controller

  def gallery_login(conn, %{"hash" => hash, "login" => %{"session_token" => token}}) do
    conn = conn |> put_session("gallery_session_token", token)
    conn |> redirect(to: Routes.gallery_client_index_path(conn, :index, hash))
  end

  def album_login(conn, %{"hash" => hash, "login" => %{"session_token" => token}}) do
    conn = conn |> put_session("album_session_token", token)
    conn |> redirect(to: Routes.gallery_client_index_path(conn, :album, hash))
  end
end
