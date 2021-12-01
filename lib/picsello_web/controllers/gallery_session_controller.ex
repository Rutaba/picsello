defmodule PicselloWeb.GallerySessionController do
  use PicselloWeb, :controller
  alias Picsello.Galleries

  def create(conn, %{"hash" => hash, "client_session" => %{"password" => password}}) do
    gallery = Galleries.get_gallery_by_hash(hash)

    if gallery.password == password do
      {:ok, token} = Galleries.build_gallery_session_token(gallery)
      conn = conn |> put_session("gallery_session_token", token.token)

      conn |> redirect(to: Routes.gallery_client_show_path(conn, :show, hash))
    else
      conn
      |> send_resp(500, "")
    end
  end
end
