defmodule PicselloWeb.GallerySessionController do
  use PicselloWeb, :controller

  def put(conn, %{"hash" => hash, "login" => %{"session_token" => token}}) do
    conn = conn |> put_session("gallery_session_token", token)
    conn |> redirect(to: Routes.gallery_client_show_path(conn, :show, hash))
  end
end
