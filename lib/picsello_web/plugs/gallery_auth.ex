defmodule PicselloWeb.Plugs.GalleryAuth do
  @moduledoc false
  @behaviour Plug
  import Plug.Conn

  alias Picsello.Galleries

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{params: %{"hash" => hash}} = conn, _params) do
    gallery = Galleries.get_gallery_by_hash(hash)

    if gallery do
      conn |> assign(:gallery, gallery)
    else
      conn |> halt
    end
  end
end
