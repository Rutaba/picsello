defmodule PicselloWeb.PageLive do
  @moduledoc false
  use PicselloWeb, live_view: [layout: :onboarding]

  @impl true
  def mount(_params, session, socket) do
    socket |> assign_defaults(session) |> ok()
  end
end
