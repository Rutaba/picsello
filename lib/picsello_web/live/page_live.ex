defmodule PicselloWeb.PageLive do
  @moduledoc false
  use PicselloWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
