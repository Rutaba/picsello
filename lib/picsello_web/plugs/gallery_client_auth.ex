defmodule PicselloWeb.Plugs.GalleryClientAuth do
  @moduledoc false
  @behaviour Plug
  import Plug.Conn

  alias Picsello.Galleries

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{} = conn, params) do 
    if user_token = get_session(conn, :gallery_client_token) do
      conn
    else
      
    end
  end
end
