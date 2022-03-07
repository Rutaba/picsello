defmodule PicselloWeb.AlbumLive.Albums do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "album"]

  @impl true
  def mount(_params, _session, socket) do
    socket |> ok()
  end
end
