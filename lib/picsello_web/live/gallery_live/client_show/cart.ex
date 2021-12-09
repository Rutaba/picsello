defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  @impl true
  def mount(_params, _session, socket), do: socket |> ok()
end
