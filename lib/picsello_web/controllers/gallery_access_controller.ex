defmodule PicselloWeb.GalleryAccessController do
  use PicselloWeb, :controller

  alias PicselloWeb.GalleryLive.ClientShowView

  def new(conn, _params) do
    #ClientShowView.render(conn, "authenticate.html")
    conn
  end
  

  
end
